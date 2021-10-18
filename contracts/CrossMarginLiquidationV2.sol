import "./CrossMarginTrading.sol";
import "./RoleAware.sol";

/// External liquidation logic
contract CrossMarginLiquidationV2 is RoleAware {
    constructor(address _roles) RoleAware(_roles) {}

    struct LiquidationRecord {
        address[] holdingTokens;
        uint256[] holdingAmounts;
        address[] borrowTokens;
        uint256[] borrowAmounts;
        uint256 liquidationBid;
        address liquidator;
        uint256 lastBidTimestamp;
    }

    mapping(address => LiquidationRecord) liquidationRecords;
    uint256 public BID_WINDOW = 5 minutes;
    uint256 public liqMaxCutPercent = 7;

    mapping(address => mapping(address => bool)) public authorizedLiquidator;

    /// Liquidate an account
    function liquidate(
        address[] memory liquidationCandidates,
        uint256[] memory bids,
        address targetAccount
    ) external {
        require(
            authorizedLiquidator[targetAccount][msg.sender],
            "Not authorized to liquidate to target account"
        );

        CrossMarginTrading cmt = CrossMarginTrading(crossMarginTrading());
        address peg = cmt.peg();

        for (
            uint256 traderIdx = 0;
            liquidationCandidates.length > traderIdx;
            traderIdx++
        ) {
            address trader = liquidationCandidates[traderIdx];
            uint256 currentBid = bids[traderIdx];
            LiquidationRecord storage lR = liquidationRecords[trader];

            bool properLiquidation =
                cmt.canBeLiquidated(trader) &&
                    currentBid * (100 + liqMaxCutPercent) >=
                    100 *
                        (cmt.viewHoldingsInPeg(trader) -
                            cmt.viewLoanInPeg(trader));

            if (
                properLiquidation ||
                (currentBid > lR.liquidationBid &&
                    lR.lastBidTimestamp + BID_WINDOW > block.timestamp)
            ) {
                if (lR.lastBidTimestamp == 0) {
                    (lR.holdingTokens, lR.holdingAmounts) = cmt
                        .getHoldingAmounts(trader);
                    (lR.borrowTokens, lR.borrowAmounts) = cmt.getBorrowAmounts(
                        trader
                    );
                    transferAssets(trader, targetAccount, lR);
                } else {
                    // repay previous liquidator
                    cmt.registerDeposit(lR.liquidator, peg, lR.liquidationBid);
                    currentBid -= lR.liquidationBid;
                    transferAssets(lR.liquidator, targetAccount, lR);
                }

                lR.liquidationBid += currentBid;
                lR.liquidator = targetAccount;
                lR.lastBidTimestamp = block.timestamp;

                cmt.registerDeposit(trader, peg, currentBid / 2);
                Fund(fund()).withdraw(peg, feeRecipient(), currentBid / 2);

                // checks positive balance
                cmt.registerTradeAndBorrow(
                    targetAccount,
                    peg,
                    peg,
                    lR.liquidationBid,
                    0
                );
            }
        }
    }

    /// Apply assets to an account
    function applyAssets(
        address recipient,
        address[] memory holdingTokens,
        uint256[] memory holdingAmounts,
        address[] memory borrowTokens,
        uint256[] memory borrowAmounts
    ) internal {
        CrossMarginTrading cmt = CrossMarginTrading(crossMarginTrading());
        for (
            uint256 holdingIdx = 0;
            holdingTokens.length > holdingIdx;
            holdingIdx++
        ) {
            cmt.registerDeposit(
                recipient,
                holdingTokens[holdingIdx],
                holdingAmounts[holdingIdx]
            );
        }
        for (
            uint256 borrowIdx = 0;
            borrowTokens.length > borrowIdx;
            borrowIdx++
        ) {
            // since at the time we didn't anticipate raw borrowing, we make a bunch of poor trades to simulate it
            cmt.registerTradeAndBorrow(
                recipient,
                borrowTokens[borrowIdx],
                holdingTokens[0],
                borrowAmounts[borrowIdx],
                0
            );
        }
    }

    /// Transfer assets from one account to another
    function transferAssets(
        address from,
        address to,
        LiquidationRecord storage lR
    ) internal {
        applyAssets(
            from,
            lR.borrowTokens,
            lR.borrowAmounts,
            lR.holdingTokens,
            lR.holdingAmounts
        );
        applyAssets(
            to,
            lR.holdingTokens,
            lR.holdingAmounts,
            lR.borrowTokens,
            lR.borrowAmounts
        );
    }

    function setliqMaxCutPercent(uint256 liqCut) external onlyOwnerExec {
        liqMaxCutPercent = liqCut;
    }

    function setBidWindow(uint256 window) external onlyOwnerExec {
        BID_WINDOW = window;
    }

    function setLiquidatorAuthorization(address liquidator, bool auth)
        external
    {
        authorizedLiquidator[msg.sender][liquidator] = auth;
    }
}
