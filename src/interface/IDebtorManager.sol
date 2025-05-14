// SPDX-License-Identifier: MIT

pragma solidity =0.8.29;

interface IDebtorManager {

    struct DebtorParams {
        int256 minCollateralRatio;   //scaled
        int256 marginBufferedCollateralRatio; //scaled
    }

    event CreateDebtor(address owner, address debtor);

    function createDebtor() external returns (address);
    function getDebtor(address _owner) external view returns (address);
    function getDebtorParams(address _debtor) external view returns (DebtorParams memory);
    function healthCheck(address _debtor) external view returns (int256 collateralRatio, 
                            bool passMinCollateralRatioCheck,
                            bool passMarginBufferedCollateralRatioCheck,
                            int256 interestReserve);
}