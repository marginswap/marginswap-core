// SPDX-License-Identifier: BUSL-1.1
import "./SpecialMigration.sol";
import "../Lending.sol";

contract LendingMigration is SpecialMigration {
    constructor(
        address _oldContract,
        address[] memory _accounts,
        address[] memory _tokens,
        uint256[] memory _amounts,
        address _roles
    ) SpecialMigration(_oldContract, _accounts, _tokens, _amounts, _roles) {}

    function _execute() internal override {
        for (uint256 j; accounts.length > j; j++) {
            Lending(lending()).makeFallbackBond(
                tokens[j],
                accounts[j],
                amounts[j]
            );
        }
    }
}
