import './RoleAware.sol';

contract Price is RoleAware {
    constructor(address _roles) RoleAware(_roles) {

    }

    function claimInsurance(address token, uint claim) external {
        require(isInsuranceClaimant(msg.sender), "Caller not authorized to claim insurance");
        // TODO
    }
}
