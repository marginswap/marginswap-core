import './RoleAware.sol';
import './MarginRouter.sol';

// Token price with rolling window
struct TokenPrice {
    uint blockLastUpdated;
    uint[] tokenPer1kHistory;
    uint currentPriceIndex;
    address[] liquidationPath;
}

contract Price is RoleAware {
    address peg;
    mapping(address => TokenPrice) tokenPrices;
    uint constant PRICE_HIST_LENGTH = 30;

    constructor(address _peg, address _roles) RoleAware(_roles) {
        peg = _peg;
    }

    function getCurrentPriceInPeg(address token, uint inAmount) external view returns (uint) {
        TokenPrice storage tokenPrice = tokenPrices[token];
        require(tokenPrice.liquidationPath.length > 1, "Token does not have a liquidation path");
        return inAmount * 1000 ether / tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex];
    }

    function getUpdatedPriceInPeg(address token, uint inAmount) external returns (uint) {
        if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            require(tokenPrice.liquidationPath.length > 1, "Token does not have a liquidation path");
            uint[] memory pathAmounts = MarginRouter(router()).getAmountsOut(AMM.uni, inAmount, tokenPrice.liquidationPath);
            uint outAmount = pathAmounts[pathAmounts.length - 1];
            tokenPrice.currentPriceIndex = (tokenPrice.currentPriceIndex + 1) % tokenPrice.tokenPer1kHistory.length;
            tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex] = 1000 ether * inAmount / outAmount;
            return outAmount;
        }
    }

    function forceUpdatedPriceInPeg(address token, uint amount) external returns (uint pegPrice) {
        // TODO don't check if it is already cached for this block
        pegPrice = 0;
    }

    function getMaxDrop(address token) external returns (uint dropInPeg) {
        // TODO biggest drop in price to current price
        dropInPeg = 0;
    }

    function getMaxRise(address token) external returns (uint riseInPeg) {
        // TODO
        riseInPeg = 0;
    }

    function claimInsurance(address token, uint claim) external {
        require(isInsuranceClaimant(msg.sender), "Caller not authorized to claim insurance");
        // TODO
    }

    // add path from token to current liquidation peg (i.e. USDC)
    function addLiquidationPath(address[] memory path) external {
        // TODO
        // make sure paths aren't excessively long
    }

    function liquidateToPeg(address token, uint amount) external {
        // TODO require caller has liquidator role
        // for each path:
        // find minimum liquidity along the route
        // set that as weight of path
    }
}
