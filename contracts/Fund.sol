// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWETH.sol";
import "./RoleAware.sol";

contract Fund is RoleAware, Ownable {
    address public WETH;
    address[] public approvedTokens;
    mapping(address => bool) public activeTokens;

    constructor(address _WETH, address _roles) Ownable() RoleAware(_roles) {
        WETH = _WETH;
    }

    function deposit(address depositToken, uint256 depositAmount)
        external
        returns (bool)
    {
        require(activeTokens[depositToken], "Deposit token is not active");
        return
            IERC20(depositToken).transferFrom(
                msg.sender,
                address(this),
                depositAmount
            );
    }

    function depositFor(
        address sender,
        address depositToken,
        uint256 depositAmount
    ) external returns (bool) {
        require(activeTokens[depositToken], "Deposit token is not active");
        require(isWithdrawer(msg.sender), "Contract not authorized to deposit");
        return
            IERC20(depositToken).transferFrom(
                sender,
                address(this),
                depositAmount
            );
    }

    function depositToWETH() external payable {
        IWETH(WETH).deposit{value: msg.value}();
    }

    // withdrawers role
    function withdraw(
        address withdrawalToken,
        address recipient,
        uint256 withdrawalAmount
    ) external returns (bool) {
        require(
            isWithdrawer(msg.sender),
            "Contract not authorized to withdraw"
        );
        return IERC20(withdrawalToken).transfer(recipient, withdrawalAmount);
    }

    // withdrawers role
    function withdrawETH(address recipient, uint256 withdrawalAmount) external {
        require(isWithdrawer(msg.sender), "Not authorized to withdraw");
        IWETH(WETH).withdraw(withdrawalAmount);
        payable(recipient).transfer(withdrawalAmount);
    }
}
