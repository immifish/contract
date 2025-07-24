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

import "./interface/IDebtor.sol";
import "../interface/IDebtorManager.sol";
import "../interface/IMinerToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Debtor is IDebtor {
    using Address for address;
    uint8 public constant VERSION = 1;

    address public immutable debtorManager;
    address public immutable minerToken;

    constructor() {
        debtorManager = msg.sender;
        minerToken = IDebtorManager(debtorManager).minerToken();
    }

    modifier debtorOwner() {
        require(address(this) == IDebtorManager(debtorManager).getDebtor(msg.sender), "Debtor: caller is not the owner");
        _;
    }

    function _isHealthy() internal view returns (bool) {
        (, bool passMinCollateralRatioCheck, , int256 interestReserveAdjusted) = IDebtorManager(debtorManager).healthCheck(address(this));
        return passMinCollateralRatioCheck && interestReserveAdjusted >= 0;
    }

    modifier keepHealthy() {
        require(_isHealthy(), "Debtor: not healthy before");
        _;
        require(_isHealthy(), "Debtor: not healthy after");
    }

    function addReserve(uint256 _amount) public {
        IMinerToken(minerToken).addReserve(address(this), _amount);
    }

    //burn, which is just transfer token to address(this)

    //add collateral, which is just transfer asset (that counts) to address(this)

    function removeReserve(address _to, uint256 _amount) public debtorOwner keepHealthy{
        IMinerToken(minerToken).removeReserve(_to, _amount);
    }

    function mint(uint256 _amount) public debtorOwner keepHealthy{
        IMinerToken(minerToken).mint(address(this), _amount);
    }

    function removeCollateral(address _token, address _to, uint256 _amount) public debtorOwner keepHealthy{
        IERC20(_token).transfer(_to, _amount);
    }

    // execute custom actions via delegatecall
    function delegateCall(address _action, bytes memory _data) public debtorOwner keepHealthy returns (bytes memory) {
        return _action.functionDelegateCall(_data);
    }

    // should be unhealthy before, and after that, the healthy status should be margined
    function liquidate(address _liquidatorAction, bytes memory _data) public returns (bytes memory) {
        (, bool passMinCollateralRatioCheck, , ) = IDebtorManager(debtorManager).healthCheck(address(this));
        require(!passMinCollateralRatioCheck, "Debtor: is healthy before");
        bytes memory result = _liquidatorAction.functionDelegateCall(_data);
        (, , bool passMarginBufferedCollateralRatioCheck, int256 interestReserveAdjusted) = IDebtorManager(debtorManager).healthCheck(address(this));
        require(passMarginBufferedCollateralRatioCheck && interestReserveAdjusted >= 0, "Debtor: not margined after");
        return result;
    }
    
}
