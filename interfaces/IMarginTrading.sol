// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

interface IMarginTrading {
    function registerDeposit(
        address trader,
        address token,
        uint256 amount
    ) external returns (uint256 extinguishAmount);

    function registerWithdrawal(
        address trader,
        address token,
        uint256 amount
    ) external;

    function registerBorrow(
        address trader,
        address token,
        uint256 amount
    ) external;

    function registerTradeAndBorrow(
        address trader,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    ) external returns (uint256 extinguishAmount, uint256 borrowAmount);
    // TODO
    // in router have list of paths..?
    // function registerLiquidation(address trader) external;
}
