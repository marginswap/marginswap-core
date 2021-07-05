import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, mfiAddress } = await getNamedAccounts();

  const legacyContract = "0x6002830D2f02D987B18d01A1CCce842ae09899d5";

  const Staking = await deploy("Staking", {
    from: deployer,
    args: [mfiAddress, mfiAddress, legacyContract],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  if (
    Staking.newlyDeployed &&
    (network.name == "localhost" || network.name == "mainnet")
  ) {
    const staking = await deployments
      .get("Staking")
      .then((Staking) => ethers.getContractAt("Staking", Staking.address));
    const tx = await staking.migrate(migrateAccounts);
  }
};

deploy.tags = ["Staking", "local"];
deploy.dependencies = ["Roles"];
export default deploy;

const migrateAccounts = [
  "0xbe3e45c2b691b3b8fdce154242d790a05c4e5507",
  "0x37ab8f80e54fb54625e16c431f0f323024cf3ae4",
  "0x907d04a0d526dfe5c9fb73d498be838ba095ddc4",
  "0x8740d9ec65b40be5ebb84bd22607e81260fe3a3a",
  "0xe0db71d26651bbcef473e467bc3f0e125d3cd4cc",
  "0x5115c67f5621440fd8413cdad36fdf89b8ac4c01",
  "0x9e1d02d853a19c7e476ced1c7c7b881d53176822",
  "0x2c941171bd2a7aeda7c2767c438dff36eaafdafc",
  "0xa7a1fe3c4e690de312b3ae911b1fd9f8e0dc79f4",
  "0x4f3b2a67ae7e6ae8bd06c86b591cc05992b2ab5a",
  "0xea2c15b73e07bdd59caec75c08f675fd4cb04229",
  "0x887C3599c4826F7b3cDe82003b894430F27d5b92",
  "0x0dc350b7a1de51c581899312070ff1c11aa5245b",
  "0xeeb4de2fb9bad3e989f6312d19344a1bc9062c81",
  "0xb7973c6d5209b1bf5c198789830b67d5fe340dad",
  "0x2bc87addae195da271c2cb6f773cee647aeefa60",
  "0xa4b89c8d5b48093d64d9b652c9da1b90bc45b232",
  "0xbacb31bce653584bd8c8ead07fa8f2eb14345294",
  "0xeb959caad3bb6e28ba3d9312a8a7ce745767249d",
  "0xc2cf6afb380aa27a4484e14225b6d40b56543ea2",
  "0x3637d7f6041d73917017e5d3e2259473215ecf6f",
  "0x7ecb9f45c167ac9724382d29b1b3f20bf550bbec",
  "0x70762806a813acacb4ba8790e26f53a131c9d0bd",
  "0x92989eb906d40c6385c9982b08c5953cbf763ab2",
  "0xa37f664fe3a42faf1e69cdb0911556e6f8c21f3c",
  "0xa0d6460b35599cc20c73fe3500a9c4a95097ea6d",
  "0xc3623db4857b7b5820fdd37199f3cb6588343902",
  "0x4c48acfaa438190661ad2f697d88a40c9634bcf0",
  "0xacdd5528c1c92b57045041b5278efa06cdade4d8",
  "0xfe362f889a2c843708daf7d32ed70ec6188a3a47",
  "0x2e27ad425fac3b8a25388bb59d086dcc70a3bb8a",
  "0xaf4e482294b2e4a7a24b06cd072e62f095a9a5bc",
  "0xcdb5ab079ef474af9230d2f7b3b5a1c6f61d2006",
  "0x0752adfe7c42d89bf2fb3c22ffa18b7d0871c807",
  "0x559b9a961f8da49d578d3dd7899612177dddfa6e",
  "0x44fc2834cdab3d22e885ef26ce1bcbe50c163ccf",
  "0x24244ef4839fda2084df4b7c0e4db4d806819cf3",
  "0x60c32eec3c9ae00a3466dbee02db4634453a9b3b",
  "0x35da61143072716e9ca1dc688e9b04145314e8d1",
  "0x0b7dc67a6ecf6bc0388409ddde919aafcf0e0ff7",
  "0x6e0e75b64010da83ba46a18e4cfd7becc23401ba",
  "0xa26bc7e6cdfe1d6e254e962a87d7fcb6941b6060",
  "0xc791f86f864cf0b7c519e6579b48b5f9351dff37",
  "0xf422dfaccf6eb15bb9f7798f9655f18799a35b1e",
  "0xe5546ea6535859c5d16373ecabde6de89fb2a4ce",
  "0xa224935d47e2160ceda9f68479f039036b3dc7ab",
  "0x84a9e0c0c3ffa1f460862c1e97521e5cdd428cad",
  "0x278f434d0e37bd3ca0974b6d2c52e9d6f6d31b81",
  "0x88f07e188d1c66bc9b567700e874160f82ed06fe",
  "0xec70538beac744eec5edec4b329205a4b29ba8ae",
  "0x8a1322ad3bfb3a127fc9295c94ea7a26963f85b8",
  "0x545600fa318f1e717756ff461cf0e7e0ecff08e3",
  "0xdbae96e97d00256a09322e1c49f062cb8bebb0f0",
  "0x3b11cc193ba3ab9c2a0ed9eda03a4d795c766262",
  "0x8b93910594e2a09c30d7e97883f6d35d8772801d",
];
