pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Presale is Ownable {
    IERC20 public MFI;
    // TODO update presale supply
    uint public constant presaleSupply = 0;
    // TODO update start date
    uint public constant startDate = 0;
    // TODO update presalePrice
    uint256 public constant presalePrice = 1;

    constructor(IERC20 tokenContract) public {
        MFI = tokenContract;
    }

    receive() external payable {
        require(startDate <= block.timestamp, "Presale hasn't started yet");

        uint tokensToTransfer = msg.value / presalePrice;
        require(tokensToTransfer <= MFI.balanceOf(address(this)), "Not enough tokens in presale contract");

        payable(owner()).transfer(msg.value);
        MFI.transfer(msg.sender, tokensToTransfer);
    }
}
