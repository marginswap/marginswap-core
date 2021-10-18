import "./PriceAware.sol";

contract TwapOracle is PriceAware, IOracle {
    constructor(
        address _peg,
        address _amm1Factory,
        address _amm2Factory,
        address _amm3Factory,
        bytes32 _amm1InitHash,
        bytes32 _amm2InitHash,
        bytes32 _amm3InitHash,
        uint256 _feeBase,
        address _roles
    )
        PriceAware(_peg)
        RoleAware(_roles)
        UniswapStyleLib(
            _amm1Factory,
            _amm2Factory,
            _amm3Factory,
            _amm1InitHash,
            _amm2InitHash,
            _amm3InitHash,
            _feeBase
        )
    {}

    function getCurrentPrice(address token, uint256 inAmount)
        external
        override
        returns (uint256)
    {
        return getCurrentPriceInPeg(token, inAmount, true);
    }

    function viewCurrentPrice(address token, uint256 inAmount)
        external
        view
        override
        returns (uint256)
    {
        return viewCurrentPriceInPeg(token, inAmount);
    }
}
