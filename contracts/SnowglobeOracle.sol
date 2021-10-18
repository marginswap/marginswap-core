import "./RoleAware.sol";
import "../interfaces/IOracle.sol";
import "./ChainlinkOracle.sol";
import "../interfaces/ISnowglobe.sol";
import "./PriceAware.sol";

contract SnowglobeOracle is ChainlinkOracle, IOracle {
    uint256 immutable pegDecimalFactor;

    struct TokenOracleParams {
        AggregatorV3Interface oracle;
        uint256 oracleDecimalFactor;
        uint256 tokenDecimalFactor;
    }

    mapping(address => TokenOracleParams) public tokenOracleParams;

    constructor(uint256 _pegDecimals, address _roles) RoleAware(_roles) {
        pegDecimalFactor = 10**_pegDecimals;
    }

    function getCurrentPrice(address token, uint256 inAmount)
        public
        override
        returns (uint256)
    {
        TokenOracleParams storage params = tokenOracleParams[token];

        (uint256 oraclePrice, uint256 tstamp) =
            getChainlinkPrice(params.oracle);

        ISnowglobe globe = ISnowglobe(token);
        if (block.timestamp > tstamp + stalenessWindow) {
            return
                (globe.getRatio() *
                    PriceAware(crossMarginTrading()).getCurrentPriceInPeg(
                        globe.token(),
                        inAmount,
                        true
                    )) / 1e18;
        } else {
            return
                (globe.getRatio() *
                    (pegDecimalFactor * inAmount * oraclePrice)) /
                params.oracleDecimalFactor /
                params.tokenDecimalFactor;
        }
    }

    function viewCurrentPrice(address token, uint256 inAmount)
        public
        view
        override
        returns (uint256)
    {
        TokenOracleParams storage params = tokenOracleParams[token];

        (uint256 oraclePrice, uint256 tstamp) =
            getChainlinkPrice(params.oracle);
        ISnowglobe globe = ISnowglobe(token);
        if (block.timestamp > tstamp + stalenessWindow) {
            return
                (globe.getRatio() *
                    PriceAware(crossMarginTrading()).viewCurrentPriceInPeg(
                        globe.token(),
                        inAmount
                    )) / 1e18;
        } else {
            return
                (globe.getRatio() *
                    (pegDecimalFactor * inAmount * oraclePrice)) /
                params.oracleDecimalFactor /
                params.tokenDecimalFactor;
        }
    }

    function setTokenOracleParameters(
        address token,
        address oracle,
        uint256 tokenDecimals
    ) external onlyOwnerExec {
        tokenOracleParams[token] = TokenOracleParams({
            oracle: AggregatorV3Interface(oracle),
            oracleDecimalFactor: 10**AggregatorV3Interface(oracle).decimals(),
            tokenDecimalFactor: 10**tokenDecimals
        });
    }
}
