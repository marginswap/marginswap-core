pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Presale is Ownable {
    IERC20 public immutable MFI;
    uint public constant presaleSupply = 5000000;
    uint public presaleIssued = 0;

    // TODO update start date
    uint public constant startDate = 0;
    uint public constant endDate = startDate + 2 days;

    // TODO update dollarsPerEth to most recent value
    uint public constant dollarsPerETH = 1381;
    uint public constant tokensPerDollar = 4;
    uint256 public constant tokensPerETH = dollarsPerETH * tokensPerDollar;

    uint public constant maxPerWallet = (10 ether * tokensPerETH);

    constructor(IERC20 tokenContract) public {
        MFI = tokenContract;
    }

    receive() external payable {
        require(startDate <= block.timestamp, "Presale hasn't started yet");
        require(endDate >= block.timestamp, "Presale is over");

        uint tokensToTransfer = msg.value * tokensPerETH;
        presaleIssued += tokensToTransfer;

        require(presaleSupply >= presaleIssued, "Not enough tokens in presale contract");
        require(maxPerWallet >= tokensToTransfer + MFI.balanceOf(msg.sender), "Wallet exceeds max presale");

        payable(owner()).transfer(msg.value);
        MFI.transferFrom(owner(), msg.sender, tokensToTransfer);
    }
}
