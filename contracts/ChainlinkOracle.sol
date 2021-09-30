import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./RoleAware.sol";

abstract contract ChainlinkOracle is RoleAware {
    mapping(address => AggregatorV3Interface) public oracles;
    uint256 public stalenessWindow = 30 minutes;

    function getChainlinkPrice(address token) public view returns (uint256, uint256, uint256) {
        AggregatorV3Interface oracle = oracles[token];
        (, int256 tokenPrice, , uint256 tstamp, ) = oracle.latestRoundData();

        return (uint256(tokenPrice), oracle.decimals(), tstamp);
    }
    
    function setChainlinkFeed(address token, address oracle) external onlyOwnerExec {
        oracles[token] = AggregatorV3Interface(oracle);
    }

    function setStalenessWindow(uint256 staleness) external onlyOwnerExec {
        stalenessWindow = staleness;
    }
}