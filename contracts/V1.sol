import "@openzeppelin/contracts/access/Ownable.sol";

import "./Roles.sol";
import "./Fund.sol";
import "./Admin.sol";
import "./CrossMarginTrading.sol";
import "./Lending.sol";
import "./MarginRouter.sol";
import "./Price.sol";

contract V1 is Ownable {
    Roles public roles;
    Fund public fund;
    Admin public admin;
    CrossMarginTrading public crossMarginTrading;
    Lending public lending;
    MarginRouter public marginRouter;
    Price public price;

    constructor(
        address targetOwner,
        address WETH,
        uint256 feesPer10k,
        address MFI,
        address uniswapFactory,
        address sushiswapFactory,
        address peg
    ) Ownable() {
        roles = new Roles();

        fund = new Fund(WETH, address(roles));
        fund.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.FUND, address(fund));

        admin = new Admin(feesPer10k, MFI, address(roles));
        admin.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.FEE_CONTROLLER, address(admin));

        crossMarginTrading = new CrossMarginTrading(address(roles));
        crossMarginTrading.transferOwnership(targetOwner);
        roles.setMainCharacter(
            Characters.MARGIN_TRADING,
            address(crossMarginTrading)
        );

        lending = new Lending(address(roles));
        lending.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.LENDING, address(lending));

        marginRouter = new MarginRouter(
            uniswapFactory,
            sushiswapFactory,
            WETH,
            address(roles)
        );
        roles.setMainCharacter(Characters.ROUTER, address(marginRouter));

        price = new Price(peg, address(roles));
        roles.setMainCharacter(Characters.PRICE_CONTROLLER, address(price));

        roles.giveRole(ContractRoles.WITHDRAWER, address(admin));
        roles.giveRole(ContractRoles.WITHDRAWER, address(marginRouter));
        roles.giveRole(ContractRoles.WITHDRAWER, address(lending));
        roles.giveRole(ContractRoles.WITHDRAWER, address(crossMarginTrading));

        roles.giveRole(ContractRoles.MARGIN_CALLER, address(admin));
        roles.giveRole(ContractRoles.BORROWER, address(marginRouter));
        roles.giveRole(ContractRoles.MARGIN_TRADER, address(marginRouter));
        roles.giveRole(ContractRoles.FEE_SOURCE, address(marginRouter));
        roles.giveRole(
            ContractRoles.INSURANCE_CLAIMANT,
            address(crossMarginTrading)
        );

        roles.transferOwnership(targetOwner);
    }
}
