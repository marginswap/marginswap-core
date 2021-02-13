import './RoleAware.sol';

// Token price with rolling window
struct TokenPrice {
    uint blockLastUpdated;
    uint[] priceHistory;
    uint8 currentPriceIndex;
}

contract Price is RoleAware {
    constructor(address _roles) RoleAware(_roles) {

    }

    function getUpdatedPriceInPeg(address token, uint amount) external returns (uint pegPrice) {
        // TODO take minimum of 1000 USD or input amount
        pegPrice = 0;
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
