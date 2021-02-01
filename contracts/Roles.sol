import "@openzeppelin/contracts/access/Ownable.sol";

contract Roles is Ownable {
    mapping(address => mapping(uint8 => bool)) public roles;
    mapping(uint8 => address) public mainCharacters;

    function giveRole(address actor, uint8 role) external onlyOwner {
        roles[actor][role] = true;
    }

    function removeRole(address actor, uint8 role) external onlyOwner {
        roles[actor][role] = false;
    }

    function setMainCharacter(uint8 role, address actor) external onlyOwner {
        mainCharacters[role] = actor;
    }

    function getRole(address contr, uint8 role) external view returns (bool) {
        return roles[contr][role];
    }
}
