import "./CrossMarginTrading.sol";
import "./RoleAware.sol";

/// External liquidation logic
contract CrossMarginLiquidationV2 is RoleAware {
    constructor(address _roles) RoleAware(_roles) {}

    uint256 public liqCutPercent = 5;

    /// Liquidate an account
    function liquidate(address[] memory liquidationCandidates, bytes32 ammPath)
        external
    {
        CrossMarginTrading cmt = CrossMarginTrading(crossMarginTrading());
        address peg = cmt.peg();

        for (
            uint256 traderIdx = 0;
            liquidationCandidates.length > traderIdx;
            traderIdx++
        ) {
            address trader = liquidationCandidates[traderIdx];

            if (cmt.canBeLiquidated(trader)) {
                uint256 debtExtinguished = liquidateDebt(trader, ammPath);
                uint256 holdingReturns = liquidateHoldings(trader, ammPath);

                if (holdingReturns > debtExtinguished + 100000) {
                    // liquidator fee is taken out of the total amount of debt extinguished
                    // though no more than the residual value of the position
                    uint256 liquidatorFee =
                        min(
                            (liqCutPercent * debtExtinguished) / 100,
                            holdingReturns - debtExtinguished
                        );
                    Fund(fund()).withdraw(peg, msg.sender, liquidatorFee);

                    // residula value after liquidator fee
                    uint256 leftOver =
                        holdingReturns - debtExtinguished - liquidatorFee;

                    // 1/3 of remainder goes to protocol
                    if (leftOver > 100000) {
                        Fund(fund()).withdraw(peg, trader, (2 * leftOver) / 3);
                        Fund(fund()).withdraw(
                            peg,
                            feeRecipient(),
                            leftOver / 3
                        );
                    }
                }

                // key: this deletes the account without further ado
                cmt.registerLiquidatorLiquidation(trader);
            }
        }
    }

    /// Liquidate the holdings of an account by trading for peg currency
    function liquidateHoldings(address trader, bytes32 ammPath)
        internal
        returns (uint256 holdingReturns)
    {
        address peg = CrossMarginTrading(crossMarginTrading()).peg();
        address WETH = MarginRouter(marginRouter()).WETH();

        (address[] memory holdingTokens, uint256[] memory holdingAmounts) =
            CrossMarginTrading(crossMarginTrading()).getHoldingAmounts(trader);

        for (
            uint256 holdingIdx;
            holdingTokens.length > holdingIdx;
            holdingIdx++
        ) {
            address token = holdingTokens[holdingIdx];
            uint256 tokenAmount = holdingAmounts[holdingIdx];

            // non-peg tokens get traded for peg tokens
            if (token != peg) {
                address[] memory tokens;
                if (token == WETH) {
                    tokens = new address[](2);
                    tokens[0] = token;
                    tokens[1] = peg;
                } else {
                    tokens = new address[](3);
                    tokens[0] = token;
                    tokens[1] = WETH;
                    tokens[2] = peg;
                }

                // pegAmount used to bound minimum output amount
                uint256 pegAmount =
                    CrossMarginTrading(crossMarginTrading())
                        .getCurrentPriceInPeg(token, tokenAmount, true);

                uint256[] memory amounts =
                    MarginRouter(marginRouter()).authorizedSwapExactT4T(
                        tokenAmount,
                        (pegAmount * 90) / 100,
                        ammPath,
                        tokens
                    );
                holdingReturns += amounts[amounts.length - 1];

            } else {
                holdingReturns += holdingAmounts[holdingIdx];
            }
        }
    }

    function liquidateDebt(address trader, bytes32 ammPath)
        internal
        returns (uint256 debtExtinguished)
    {
        address peg = CrossMarginTrading(crossMarginTrading()).peg();
        address WETH = MarginRouter(marginRouter()).WETH();

        (address[] memory borrowTokens, uint256[] memory borrowAmounts) =
            CrossMarginTrading(crossMarginTrading()).getBorrowAmounts(trader);

        for (uint256 borrowIdx; borrowTokens.length > borrowIdx; borrowIdx++) {
            address token = borrowTokens[borrowIdx];
            uint256 tokenAmount = borrowAmounts[borrowIdx];

            // non-peg tokens get bought with peg
            if (token != peg) {
                address[] memory tokens;
                if (token == WETH) {
                    tokens = new address[](2);
                    tokens[0] = peg;
                    tokens[1] = token;
                } else {
                    tokens = new address[](3);
                    tokens[0] = peg;
                    tokens[1] = WETH;
                    tokens[2] = token;
                }

                // pegAmount used to bound maximum input amount
                uint256 pegAmount =
                    CrossMarginTrading(crossMarginTrading())
                        .getCurrentPriceInPeg(token, tokenAmount, true);

                uint256[] memory amounts =
                    MarginRouter(marginRouter()).authorizedSwapT4ExactT(
                        tokenAmount,
                        (pegAmount * 111) / 100,
                        ammPath,
                        tokens
                    );
                debtExtinguished += amounts[0];

            } else {
                debtExtinguished += tokenAmount;
            }

            // reduce the amount of borrowing in this token
            Lending(lending()).payOff(token, tokenAmount);
        }
    }

    function setliqCutPercent(uint256 liqCut) external onlyOwnerExec {
        liqCutPercent = liqCut;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }
}
