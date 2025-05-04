// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interface/IBlockUpdater.sol";
import "./interface/IMinerToken.sol";
import "./lib/int257.sol";

contract MinerToken is Initializable, IMinerToken, ERC20Upgradeable, OwnableUpgradeable {
    using Address for address;
    using Int257Lib for Int257Lib.Int257;

    event DesignatedBeneficiaryUpdated(address indexed settlor, address indexed beneficiary, address indexed operator);

    struct TimeStamp {
        uint256 lastModifiedEpoch;
        uint256 lastModifiedTime;
    }
    
    /// @notice there is no balance because we use token balance
    struct Yield {
        TimeStamp timeStamp;
        uint256 interestFactor;
        uint256 interest;
    }

    /// @notice the balance is short position balance
    struct Obligation {
        TimeStamp timeStamp;
        uint256 outStandingBalance;
        uint256 debtFactor;
        Int257Lib.Int257 interestReserve;
    }

    /// @notice the addresses of the creditors and debtors are mutually exclusive,
    /// @notice the creditor can be token holder, but the debtor can not hold any token
    /// @notice this mechanism should be guaranteed by top layer functions
    mapping(address => Yield) _creditors;
    mapping(address => Obligation) _debtors;

    // most contract can not claim interest as creditor, so we need to designate a beneficiary
    mapping(address => address) _designatedBeneficiary;

    IERC20 _interestToken;
    IBlockUpdater _blockUpdater;

    // addresses for other contracts to call
    address _debtorManager;
    address _valuationService;

    // Decimals for the token
    uint8 _decimals;

    function isDebtor(address _debtor) public view returns (bool) {
        return _debtors[_debtor].timeStamp.lastModifiedTime > 0;
    }

    // Initializer function to set up the token
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address interestToken_,
        address blockUpdater_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        _decimals = decimals_;
        __Ownable_init(msg.sender);   // Initialize the Ownable contract with the deployer as the owner
        _interestToken = IERC20(interestToken_); // Set the interest token address
        _blockUpdater = IBlockUpdater(blockUpdater_);
    }

    // Override the decimals function to return the custom decimals value
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function interestToken() public view override returns (address) {
        return address(_interestToken);
    }

    // reserved for upgrade
    function setBlockUpdater(address _newBlockUpdater) public onlyOwner {
        _blockUpdater = IBlockUpdater(_newBlockUpdater);
    }

    function blockUpdater() public view override returns (address) {
        return address(_blockUpdater);
    }

    function setDebtorManager(address _newDebtorManager) public onlyOwner {
        _debtorManager = _newDebtorManager;
    }

    function setValuationService(address _newValuationService) public onlyOwner {
        _valuationService = _newValuationService;
    }

    function valuationService() public view returns (address) {
        return _valuationService;
    }

    // redirect the interest to designated beneficiary. The beneficiary can claim interest for the settlor
    function setDesignatedBeneficiary(address _settlor, address _beneficiary) public {
        require(_settlor != address(0), "MinerToken: settlor cannot be zero address");
        require(_beneficiary != address(0), "MinerToken: beneficiary cannot be zero address");
        
        if (_msgSender() == _settlor || _msgSender() == owner()) {
            _designatedBeneficiary[_settlor] = _beneficiary;
            emit DesignatedBeneficiaryUpdated(_settlor, _beneficiary, _msgSender());
        } else {
            revert("MinerToken: caller must be settlor or owner");
        }
    }

    function getDesignatedBeneficiary(address _settlor) public view returns (address) {
        return _designatedBeneficiary[_settlor];
    }

    function _settleCreditor(address _creditor) public {
        Yield storage creditor = _creditors[_creditor];
        if (creditor.timeStamp.lastModifiedTime == block.timestamp) {
            return;
        }
        // if not initialized, only need to update the timeStamp (init)
        if (creditor.timeStamp.lastModifiedTime > 0){
            (uint256 epochReward, uint256 newInterestFactor) = _blockUpdater
            .pendingReward(
                balanceOf(_creditor),
                creditor.timeStamp.lastModifiedEpoch,
                creditor.timeStamp.lastModifiedTime,
                creditor.interestFactor
            );
            creditor.interestFactor = newInterestFactor;
            creditor.interest += epochReward;
            creditor.timeStamp.lastModifiedTime = block.timestamp;
        }
        if (creditor.timeStamp.lastModifiedEpoch != _blockUpdater.getCurrentEpoch()) {
            creditor.timeStamp.lastModifiedEpoch = _blockUpdater.getCurrentEpoch();
        }
    }

    function _settleDebtor(address _debtor) public {
        Obligation storage debtor = _debtors[_debtor];
        if (debtor.timeStamp.lastModifiedTime == block.timestamp) {
            return;
        }
        // if not initialized, only need to update the timeStamp (init)
        if (debtor.timeStamp.lastModifiedTime > 0){
            (uint256 epochDebt, uint256 newDebtFactor) = _blockUpdater
                .pendingReward(
                    debtor.outStandingBalance,
                    debtor.timeStamp.lastModifiedEpoch,
                    debtor.timeStamp.lastModifiedTime,
                    debtor.debtFactor
                );
            debtor.debtFactor = newDebtFactor;
            debtor.interestReserve.subStorage(epochDebt);
        }

        debtor.timeStamp.lastModifiedTime = block.timestamp;
        if (debtor.timeStamp.lastModifiedEpoch != _blockUpdater.getCurrentEpoch()) {
            debtor.timeStamp.lastModifiedEpoch = _blockUpdater.getCurrentEpoch();
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
        Yield storage creditorYield = _creditors[_creditor];
        if (creditorYield.interest < _amount) {
            revert MinerTokenInsufficientInterest(_creditor, creditorYield.interest, _amount);
        }
        // Update interest balance and transfer tokens
        unchecked {
            creditorYield.interest -= _amount;
        }
        _interestToken.transfer(_to, _amount);
        emit ClaimReward(_creditor, _to, _amount);
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
            emit Mint(from, to, value);
        } else {
            // from is creditor
            _settleCreditor(from);
            if (isDebtor(to)) {
                // transfer to debtor means to reduce the outStandingBalance by burning token
                Obligation storage debtor = _debtors[to];
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
        _update(_debtor, _to, _amount);
    }

    // this can only be called by debtor
    function removeReserve(uint256 _amount) public {
        address _debtor = _msgSender();
        require(isDebtor(_debtor), "MinerToken: cannot remove reserve from non-debtor");
        Int257Lib.Int257 storage interestReserve = _debtors[_debtor].interestReserve;
        require(!interestReserve.isNegative() && interestReserve.magnitude >= _amount, "MinerToken: insufficient interest reserve");
        interestReserve.subStorage(_amount);
        _interestToken.transfer(_debtor, _amount);
        emit RemoveReserve(_debtor, _amount);
    }
    
    // no need to settle for saving gas
    function addReserve(address _debtor, uint256 _amount) public {
        require(isDebtor(_debtor), "MinerToken: cannot add reserve to non-debtor");
        _interestToken.transferFrom(_msgSender(), address(this), _amount);
        Int257Lib.Int257 storage interestReserve = _debtors[_debtor].interestReserve;
        interestReserve.addStorage(_amount);
        emit AddReserve(_debtor, _amount);
    }

    // simluate settle to give interest reserve result
    function queryInterestReserve(address _debtor) public view returns (uint256 reserve, bool isNegative) {
        Obligation storage debtor = _debtors[_debtor];
        (uint256 epochDebt, ) = _blockUpdater
                .pendingReward(
                    debtor.outStandingBalance,
                    debtor.timeStamp.lastModifiedEpoch,
                    debtor.timeStamp.lastModifiedTime,
                    debtor.debtFactor
                );
        Int257Lib.Int257 memory result = debtor.interestReserve.subMemory(epochDebt);
        return (result.magnitude, result.negative);
    }

}
