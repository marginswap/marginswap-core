import "./RoleAware.sol";
import "../interfaces/IOracle.sol";
import "./ChainlinkOracle.sol";
import "../interfaces/ISnowglobe.sol";
import "./PriceAware.sol";

contract SnowglobeOracle is ChainlinkOracle, IOracle {
    uint256 immutable pegDecimals;
    constructor(uint256 _pegDecimals, address _roles) RoleAware(_roles) {
        pegDecimals = _pegDecimals;
    }

    function getCurrentPrice(address token, uint256 inAmount) public override returns (uint256) {
        (uint256 oraclePrice, uint256 oracleDecimals, uint256 tstamp) = getChainlinkPrice(token);
        ISnowglobe globe = ISnowglobe(token);
        if (block.timestamp > tstamp + stalenessWindow) {
            return globe.getRatio() * PriceAware(crossMarginTrading()).getCurrentPriceInPeg(globe.token(), inAmount, true) / 1e18;
        } else {
        return globe.getRatio() * (pegDecimals * inAmount * oraclePrice) / (10 ** oracleDecimals) / 1e18;
        }
    }

    function viewCurrentPrice(address token, uint256 inAmount) public override view returns (uint256) {
        (uint256 oraclePrice, uint256 oracleDecimals, uint256 tstamp) = getChainlinkPrice(token);
        ISnowglobe globe = ISnowglobe(token);
        if (block.timestamp > tstamp + stalenessWindow) {
            return globe.getRatio() * PriceAware(crossMarginTrading()).viewCurrentPriceInPeg(globe.token(), inAmount) / 1e18;
        } else {
        return globe.getRatio() * (pegDecimals * inAmount * oraclePrice) / (10 ** oracleDecimals) / 1e18;
        }
    }
}