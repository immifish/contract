// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICycleUpdater} from "./interface/ICycleUpdater.sol";
import {IMinerToken} from "./interface/IMinerToken.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract MinerToken is Initializable, IMinerToken, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Address for address;
    using SafeERC20 for IERC20;

    event DesignatedBeneficiaryUpdated(address indexed settlor, address indexed beneficiary, address indexed operator);

    

    /// @notice the addresses of the creditors and debtors are mutually exclusive,
    /// @notice the creditor can be token holder, but the debtor can not hold any token
    /// @notice this mechanism should be guaranteed by top layer functions
    mapping(address => Creditor) _creditors;
    mapping(address => Debtor) _debtors;

    // most contract can not claim interest as creditor, so we need to designate a beneficiary
    mapping(address => address) _designatedBeneficiary;

    IERC20 _interestToken;
    ICycleUpdater _cycleUpdater;

    // addresses for other contracts to call
    address _debtorManager;

    // Decimals for the token
    uint8 _decimals;

    // Platform fee
    address public _feeReceiver;
    uint256 public _feeRate; // 10000 = 100%

    function isDebtor(address _debtor) public view returns (bool) {
        return _debtors[_debtor].timeStamp.lastModifiedTime > 0;
    }

    //todo it has the same name with getDebtor in DebtorManager.sol should change later
    function getDebtor(address _debtor) public view returns (Debtor memory) {
        return _debtors[_debtor];
    }

    // Initializer function to set up the token
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address interestToken_,
        address cycleUpdater_,
        address feeReceiver_,
        uint256 feeRate_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        _decimals = decimals_;
        __Ownable_init(msg.sender);   // Initialize the Ownable contract with the deployer as the owner
        __UUPSUpgradeable_init();
        _interestToken = IERC20(interestToken_); // Set the interest token address
        _cycleUpdater = ICycleUpdater(cycleUpdater_);
        _feeReceiver = feeReceiver_;
        _feeRate = feeRate_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function interestToken() public view override returns (address) {
        return address(_interestToken);
    }

    // reserved for upgrade
    function setCycleUpdater(address _newCycleUpdater) public onlyOwner {
        _cycleUpdater = ICycleUpdater(_newCycleUpdater);
    }

    function cycleUpdater() public view override returns (address) {
        return address(_cycleUpdater);
    }

    function setDebtorManager(address _newDebtorManager) public onlyOwner {
        _debtorManager = _newDebtorManager;
    }

    // redirect the interest to designated beneficiary. The beneficiary can claim interest for the settlor
    function setDesignatedBeneficiary(address _creditor, address _beneficiary) public {
        require(_creditor != address(0), "MinerToken: creditor cannot be zero address");
        require(_beneficiary != address(0), "MinerToken: beneficiary cannot be zero address");
        
        if (_msgSender() == _creditor || _msgSender() == owner()) {
            _designatedBeneficiary[_creditor] = _beneficiary;
            emit DesignatedBeneficiaryUpdated(_creditor, _beneficiary, _msgSender());
        } else {
            revert("MinerToken: caller must be creditor or owner");
        }
    }

    function getDesignatedBeneficiary(address _creditor) public view returns (address) {
        return _designatedBeneficiary[_creditor];
    }

    function settleCreditorPreview(address _creditor) public view returns (uint256 claimableInterest) {
        //address should not be a debtor
        require(!isDebtor(_creditor), "MinerToken: creditor must not be debtor");
        Creditor storage creditor = _creditors[_creditor];
        (uint256 epochReward,) = _cycleUpdater
            .interestPreview(
                balanceOf(_creditor),
                creditor.timeStamp.lastModifiedCycle,
                creditor.timeStamp.lastModifiedTime,
                creditor.interestFactor
            );
        claimableInterest = creditor.interest + epochReward;
    }

    function _settleCreditor(address _creditor) public {
        Creditor storage creditor = _creditors[_creditor];
        if (creditor.timeStamp.lastModifiedTime == block.timestamp) {
            return;
        }
        // if not initialized, only need to update the timeStamp (init)
        if (creditor.timeStamp.lastModifiedTime > 0){
            (uint256 epochReward, uint256 newInterestFactor) = _cycleUpdater
            .interestPreview(
                balanceOf(_creditor),
                creditor.timeStamp.lastModifiedCycle,
                creditor.timeStamp.lastModifiedTime,
                creditor.interestFactor
            );
            creditor.interestFactor = newInterestFactor;
            creditor.interest += epochReward;
        }
        creditor.timeStamp.lastModifiedTime = block.timestamp;
        if (creditor.timeStamp.lastModifiedCycle != _cycleUpdater.getCurrentCycleIndex()) {
            creditor.timeStamp.lastModifiedCycle = _cycleUpdater.getCurrentCycleIndex();
        }
    }

    function _settleDebtor(address _debtor) public {
        Debtor storage debtor = _debtors[_debtor];
        if (debtor.timeStamp.lastModifiedTime == block.timestamp) {
            return;
        }
        // if not initialized, only need to update the timeStamp (init)
        if (debtor.timeStamp.lastModifiedTime > 0){
            (uint256 epochDebt, uint256 newDebtFactor) = _cycleUpdater
                .interestPreview(
                    debtor.outStandingBalance,
                    debtor.timeStamp.lastModifiedCycle,
                    debtor.timeStamp.lastModifiedTime,
                    debtor.debtFactor
                );
            debtor.debtFactor = newDebtFactor;
            debtor.interestReserve -= SafeCast.toInt256(epochDebt);
        }

        debtor.timeStamp.lastModifiedTime = block.timestamp;
        if (debtor.timeStamp.lastModifiedCycle != _cycleUpdater.getCurrentCycleIndex()) {
            debtor.timeStamp.lastModifiedCycle = _cycleUpdater.getCurrentCycleIndex();
        }
    }

    function registerDebtor(address _debtor) public {
        require(msg.sender == _debtorManager, "MinerToken: caller must be debtor manager");
        require(!isDebtor(_debtor), "MinerToken: debtor already exists");
        _settleDebtor(_debtor);
        emit RegisterDebtor(_debtor);
    }

    // claim interest of creditor, can call by owner or designated beneficiary
    /**
     * @notice Allows creditors or their designated beneficiaries to claim earned interest
     * @param _creditor The address of the creditor whose interest is being claimed
     * @param _to The address to receive the claimed interest
     * @param _amount The amount of interest to claim
     */
    function claim(address _creditor, address _to, uint256 _amount) external {
        if (isDebtor(_creditor)) {
            revert("MinerToken: creditor must not be debtor");
        }
        // Validate caller is authorized
        if (msg.sender != _creditor && msg.sender != _designatedBeneficiary[_creditor]) {
            revert("MinerToken: caller must be creditor or designated beneficiary");
        }
        // Update creditor's interest
        _settleCreditor(_creditor);
        // Check sufficient interest available
        Creditor storage creditor = _creditors[_creditor];
        if (creditor.interest < _amount) {
            revert MinerTokenInsufficientInterest(_creditor, creditor.interest, _amount);
        }
        // Update interest balance and transfer tokens
        unchecked {
            creditor.interest -= _amount;
        }
        _interestToken.safeTransfer(_to, _amount);
        emit Claim(_creditor, _to, _amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        // as a debtor can never hold any token, is from is debtor, then it means debtor
        // mint token for a non-debtor.
        if (isDebtor(from)) {
            // from is debtor
            // mint token for a non-debtor.
            require(!isDebtor(to), "MinerToken: cannot mint to debtor");
            _settleDebtor(from);
            _settleCreditor(to);
            _debtors[from].outStandingBalance += value;
            super._update(address(0), to, value);
        } else {
            // from is creditor
            _settleCreditor(from);
            if (isDebtor(to)) {
                // transfer to debtor means to reduce the outStandingBalance by burning token
                Debtor storage debtor = _debtors[to];
                if (debtor.outStandingBalance < value) {
                    revert("MinerToken: insufficient outStandingBalance");
                } else {
                    _settleDebtor(to);
                    debtor.outStandingBalance -= value;
                    super._update(from, address(0), value);
                    emit Burn(from, to, value);
                }
            } else {
                // normal transfer between creditors
                _settleCreditor(to);
                super._update(from, to, value);
            }
        }
    }

    function mint(address _to, uint256 _amount) public {
        address _debtor = _msgSender();
        require(isDebtor(_debtor), "MinerToken: cannot mint by a non-debtor");
        require(_to != address(0), "MinerToken: cannot mint to zero address");
        require(!isDebtor(_to), "MinerToken: cannot mint to debtor");
        uint256 fee = _amount * _feeRate / 10000;
        uint256 amount = _amount - fee;
        _update(_debtor, _to, amount);
        if (fee > 0) {
            _update(_debtor, _feeReceiver, fee);
        }
        emit Mint(_debtor, _to, amount, fee);
    }

    // this can only be called by debtor
    function removeReserve(address _to, uint256 _amount) public {
        address _debtor = _msgSender();
        require(isDebtor(_debtor), "MinerToken: cannot remove reserve from non-debtor");
        Debtor storage debtor = _debtors[_debtor];
        require(debtor.interestReserve >= 0 && uint256(debtor.interestReserve) >= _amount, "MinerToken: insufficient interest reserve");
        debtor.interestReserve -= SafeCast.toInt256(_amount);
        _interestToken.safeTransfer(_to, _amount);
        emit RemoveReserve(_debtor, _amount);
    }
    
    // no need to settle for saving gas
    function addReserve(address _debtor, uint256 _amount) public {
        require(isDebtor(_debtor), "MinerToken: cannot add reserve to non-debtor");
        _interestToken.safeTransferFrom(_msgSender(), address(this), _amount);
        _debtors[_debtor].interestReserve += SafeCast.toInt256(_amount);
        emit AddReserve(_debtor, _amount);
    }

}
