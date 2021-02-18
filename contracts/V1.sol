import "@openzeppelin/contracts/access/Ownable.sol";

import "./Roles.sol";
import "./Fund.sol";
import "./Admin.sol";
import "./MarginTrading.sol";
import "./Lending.sol";
import "./MarginRouter.sol";
import "./MarginTrading.sol";
import "./Price.sol";

contract V1 is Ownable {
    constructor(
        address targetOwner,
        address WETH,
        uint256 feesPer10k,
        address MFI,
        address uniswapFactory,
        address sushiswapFactory,
        address peg
    ) Ownable() {
        Roles roles = new Roles();

        Fund fund = new Fund(WETH, address(roles));
        fund.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.FUND, address(fund));

        Admin admin = new Admin(feesPer10k, MFI, address(roles));
        admin.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.FEE_CONTROLLER, address(admin));

        MarginTrading marginTrading = new MarginTrading(address(roles));
        marginTrading.transferOwnership(targetOwner);
        roles.setMainCharacter(
            Characters.MARGIN_TRADING,
            address(marginTrading)
        );

        Lending lending = new Lending(address(roles));
        lending.transferOwnership(targetOwner);
        roles.setMainCharacter(Characters.LENDING, address(lending));

        MarginRouter marginRouter =
            new MarginRouter(
                uniswapFactory,
                sushiswapFactory,
                WETH,
                address(roles)
            );
        roles.setMainCharacter(Characters.ROUTER, address(marginRouter));

        Price price = new Price(peg, address(roles));
        roles.setMainCharacter(Characters.PRICE_CONTROLLER, address(price));

        roles.giveRole(ContractRoles.WITHDRAWER, address(admin));
        roles.giveRole(ContractRoles.WITHDRAWER, address(marginRouter));
        roles.giveRole(ContractRoles.WITHDRAWER, address(lending));
        roles.giveRole(ContractRoles.WITHDRAWER, address(marginTrading));

        roles.giveRole(ContractRoles.MARGIN_CALLER, address(admin));
        roles.giveRole(ContractRoles.BORROWER, address(marginRouter));
        roles.giveRole(ContractRoles.MARGIN_TRADER, address(marginRouter));
        roles.giveRole(ContractRoles.FEE_SOURCE, address(marginRouter));
        roles.giveRole(
            ContractRoles.INSURANCE_CLAIMANT,
            address(marginTrading)
        );

        roles.transferOwnership(targetOwner);
    }
}
