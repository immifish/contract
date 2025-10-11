// SPDX-License-Identifier: MIT

/**
    Debtor Action Design Guide:

    Action table for [OWNER]:
             |  in debt                                | not in debt     
    Margined |  add reserve, burn, add collateral      | add reserve, remove reserve, mint, burn, add collateral, remove collateral, custom actions
    Healthy  |  add reserve, burn, add collateral      | add reserve, remove reserve, mint, burn, add collateral, remove collateral, custom actions
    Unhealthy|  add reserve, burn, add collateral      | add reserve, burn, add collateral

    Observing this table we can find that:
    add reserve, burn, add collateral do not need condition check. So we can simplify the table as follows:

               |  in debt | not in debt     
    Healthy    |    none  | remove reserve, mint, remove collateral, custom actions
    Unhealthy  |    none  | 
    *All status| add reserve, burn, add collateral

    Action table for [LIQUIDATOR]:  
    Healthy    |  none  
    Unhealthy  |  liquidate (after that, the healthy status should be margined)

*/

pragma solidity ^0.8.0;

import {IDebtor} from "./interface/IDebtor.sol";
import {IDebtorManager} from "../interface/IDebtorManager.sol";
import {IMinerToken} from "../interface/IMinerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Debtor is IDebtor, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    uint8 public constant VERSION = 1;

    address public immutable DEBTOR_MANAGER;
    address public immutable MINER_TOKEN;

    constructor() {
        DEBTOR_MANAGER = msg.sender;
        MINER_TOKEN = IDebtorManager(DEBTOR_MANAGER).minerToken();
    }

    modifier debtorOwner() {
        require(address(this) == IDebtorManager(DEBTOR_MANAGER).getDebtor(msg.sender), "Debtor: caller is not the owner");
        _;
    }

    function _isHealthy() internal view returns (bool) {
        (, bool passMinCollateralRatioCheck, , int256 interestReserveAdjusted) = IDebtorManager(DEBTOR_MANAGER).healthCheck(address(this));
        return passMinCollateralRatioCheck && interestReserveAdjusted >= 0;
    }

    modifier keepHealthy() {
        require(_isHealthy(), "Debtor: not healthy before");
        _;
        require(_isHealthy(), "Debtor: not healthy after");
    }

    function addReserve(uint256 _amount) public {
        IMinerToken(MINER_TOKEN).addReserve(address(this), _amount);
    }

    //burn, which is just transfer token to address(this)

    //add collateral, which is just transfer asset (that counts) to address(this)

    function removeReserve(address _to, uint256 _amount) public debtorOwner keepHealthy{
        IMinerToken(MINER_TOKEN).removeReserve(_to, _amount);
    }

    function mint(uint256 _amount) public debtorOwner keepHealthy{
        IMinerToken(MINER_TOKEN).mint(address(this), _amount);
    }

    function removeCollateral(address _token, address _to, uint256 _amount) public debtorOwner keepHealthy{
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function debtorManager() external view returns (address) {
        return DEBTOR_MANAGER;
    }

    // execute custom actions via delegatecall
    function delegateCall(address _action, bytes memory _data) public debtorOwner keepHealthy nonReentrant returns (bytes memory) {
        return _action.functionDelegateCall(_data);
    }

    // should be unhealthy before, and after that, the healthy status should be margined
    function liquidate(address _liquidatorAction, bytes memory _data) public nonReentrant returns (bytes memory) {
        (, bool passMinCollateralRatioCheck, , ) = IDebtorManager(DEBTOR_MANAGER).healthCheck(address(this));
        require(!passMinCollateralRatioCheck, "Debtor: is healthy before");
        bytes memory result = _liquidatorAction.functionDelegateCall(_data);
        (, , bool passMarginBufferedCollateralRatioCheck, int256 interestReserveAdjusted) = IDebtorManager(DEBTOR_MANAGER).healthCheck(address(this));
        require(passMarginBufferedCollateralRatioCheck && interestReserveAdjusted >= 0, "Debtor: not margined after");
        return result;
    }
    
}
