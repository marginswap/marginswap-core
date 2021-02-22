import "./RoleAware.sol";
import "./MarginRouter.sol";

// Token price with rolling window
struct TokenPrice {
    uint256 blockLastUpdated;
    uint256[] tokenPer1kHistory;
    uint256 currentPriceIndex;
    address[] liquidationPath;
    address[] inverseLiquidationPath;
}

contract Price is RoleAware {
    address public peg;
    mapping(address => TokenPrice) tokenPrices;
    uint256 constant PRICE_HIST_LENGTH = 30;

    constructor(address _peg, address _roles) RoleAware(_roles) {
        peg = _peg;
    }

    function getCurrentPriceInPeg(address token, uint256 inAmount)
        external
        view
        returns (uint256)
    {
        TokenPrice storage tokenPrice = tokenPrices[token];
        require(
            tokenPrice.liquidationPath.length > 1,
            "Token does not have a liquidation path"
        );
        return
            (inAmount * 1000 ether) /
            tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex];
    }

    function getUpdatedPriceInPeg(address token, uint256 inAmount)
        external
        returns (uint256)
    {
        if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            require(
                tokenPrice.liquidationPath.length > 1,
                "Token does not have a liquidation path"
            );
            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsOut(
                    AMM.uni,
                    inAmount,
                    tokenPrice.liquidationPath
                );
            uint256 outAmount = pathAmounts[pathAmounts.length - 1];
            tokenPrice.currentPriceIndex =
                (tokenPrice.currentPriceIndex + 1) %
                tokenPrice.tokenPer1kHistory.length;
            tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex] =
                (1000 ether * inAmount) /
                outAmount;
            return outAmount;
        }
    }

    // TODO rename to amounts in / out
    function getCostInPeg(address token, uint256 outAmount)
        external
        view
        returns (uint256)
    {
        if (token == peg) {
            return outAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            require(
                tokenPrice.inverseLiquidationPath.length > 1,
                "Token does not have a liquidation path"
            );

            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsIn(
                    AMM.uni,
                    outAmount,
                    tokenPrice.inverseLiquidationPath
                );
            uint256 inAmount = pathAmounts[0];
            return inAmount;
        }
    }

    function forceUpdatedPriceInPeg(address token, uint256 amount)
        external
        returns (uint256 pegPrice)
    {
        // TODO don't check if it is already cached for this block
        pegPrice = 0;
    }

    function getMaxDrop(address token) external returns (uint256 dropInPeg) {
        // TODO biggest drop in price to current price
        dropInPeg = 0;
    }

    function getMaxRise(address token) external returns (uint256 riseInPeg) {
        // TODO
        riseInPeg = 0;
    }

    function claimInsurance(address token, uint256 claim) external {
        require(
            isInsuranceClaimant(msg.sender),
            "Caller not authorized to claim insurance"
        );
        // TODO
    }

    // add path from token to current liquidation peg (i.e. USDC)
    function addLiquidationPath(address[] memory path) external {
        // TODO
        // make sure paths aren't excessively long
        // add the inverse as well
    }

    function liquidateToPeg(address token, uint256 amount) external {
        // TODO require caller has liquidator role
        // for each path:
        // find minimum liquidity along the route
        // set that as weight of path
    }
}
