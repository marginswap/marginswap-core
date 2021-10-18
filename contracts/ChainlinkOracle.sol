import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./RoleAware.sol";

abstract contract ChainlinkOracle is RoleAware {
    uint256 public stalenessWindow = 30 minutes;

    function getChainlinkPrice(AggregatorV3Interface oracle)
        public
        view
        returns (uint256, uint256)
    {
        (, int256 tokenPrice, , uint256 tstamp, ) = oracle.latestRoundData();

        return (uint256(tokenPrice), tstamp);
    }

    function setStalenessWindow(uint256 staleness) external onlyOwnerExec {
        stalenessWindow = staleness;
    }
}
