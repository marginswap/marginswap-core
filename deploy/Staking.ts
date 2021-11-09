import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import { parseEther } from '@ethersproject/units';
import { BigNumber } from 'ethers';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, mfiAddress } = await getNamedAccounts();

  const legacyContract = '0x6002830D2f02D987B18d01A1CCce842ae09899d5';
  const interimAddress = '0x072379C47Dd69dc7F2377E366b5e52D27256FD2B';

  const interim = await ethers.getContractAt('Staking', interimAddress);

  // const _migrateAccounts: string[] = [];
  // for (const account of migrateAccounts) {
  //   const balance = await interim.balanceOf(account);
  //   const min = parseEther('20');
  //   if (balance.gt(min) || (await interim.rewards(account)).gt(min)) {
  //     _migrateAccounts.push(account);
  //   }
  // }

  // console.log(_migrateAccounts);

  // const Staking = await deploy('Staking', {
  //   from: deployer,
  //   args: [mfiAddress, mfiAddress, legacyContract, interimAddress],
  //   log: true,
  //   // skipIfAlreadyDeployed: true
  // });

  // if (//Staking.newlyDeployed &&
  //    (network.name == 'localhost' || network.name == 'mainnet')) {
  //   const staking = await deployments.get('Staking').then(Staking => ethers.getContractAt('Staking', Staking.address));

  //   const userRewardPerTokenPaid: BigNumber[] = [];
  //   const rewards: BigNumber[] = [];
  //   const stakeStart: BigNumber[] = [];
  //   const accountBalances: BigNumber[] = [];
  //   const isMigrated: boolean[] = [];

  //   for (const account of migrateAccounts) {
  //     userRewardPerTokenPaid.push(await interim.userRewardPerTokenPaid(account));
  //     rewards.push(await interim.rewards(account));
  //     stakeStart.push(await interim.stakeStart(account));
  //     accountBalances.push(await interim.balanceOf(account));
  //     isMigrated.push(await interim.migrated(account));
  //   }

  //   let tx = await staking.functions.migrateAccounts(
  //     // await interim.rewardPerTokenStored(),
  //     // await interim.totalSupply(),

  //     migrateAccounts,
  //     userRewardPerTokenPaid,
  //     rewards,
  //     stakeStart,
  //     accountBalances,
  //     isMigrated,
  //     {gasLimit: 10626570 }
  //   );
  //   console.log(`Migrating at ${tx.hash}`);
  //   tx = await tx.wait();
  //   console.log(`Migrated with ${tx.gasUsed}`);
  //   // tx = await staking.migrateAccounts(migrateAccounts.slice(migrateAccounts.length / 2));
  //   // console.log(`Migrating at ${tx.hash}`);
  //   // await tx.wait();

  //   // tx = await staking.migrateParams();
  //   // console.log(`Migrating params at ${tx.hash}`);
  //   // await tx.wait();
  // }
};

deploy.tags = ['Staking', 'local'];
deploy.dependencies = [];
export default deploy;

const migrateAccounts = [
  '0x1d002965923ba11b4d56030d2cfd6ee30325a944',
  '0x16f3fc1e4ba9d70f47387b902fa5d21020b5c6b5',
  '0x106a69f7721503114785d36866e5d37d2befc549',
  '0xc87d6fd2b03554bca205aac771ab67a041ee8902',
  '0x9495c18e1b7e0b026f8eef3d087d9822c2b70da0',
  '0x60c32eec3c9ae00a3466dbee02db4634453a9b3b',
  '0xc074887d140e276a8b892222f925440eaf3ff40b',
  '0x6c7ea81bb46ec44720af326a25df1dde93bc4b87',
  '0xd01d7d004dc1c37f01115f9d8c9b1e668cfcac9e',
  '0x0079ce80043edc3325598e4a3b6293ab779bf174',
  '0xebb2ca5d1b22f5f39e386066c5fd36171d3cd536',
  '0x2fc9896cb056cd3f28716ada06e509a1c8fed40f',
  '0x4229a48a1c3d0526a5ff78a376f33e2d8c3ab5a3',
  '0x336bfa87e446267fbc2c9dab2951e18181e269ea',
  '0xdc42911845e5111b49b889910b0ad5f3939320c4',
  '0xb124c2e19b7de50db658e899d5ecf0a88dc6d99c',
  '0xbd0e8a1011af627e556f2ce595665aa5b78adcb5',
  '0xbe5996aefcb9564f6f8b7054dda23a9bc156285a',
  '0xc3f3999f8df40474a9f9fe8403837d018778c80d',
  '0xbe3e45c2b691b3b8fdce154242d790a05c4e5507',
  '0x70762806a813acacb4ba8790e26f53a131c9d0bd',
  '0x37ab8f80e54fb54625e16c431f0f323024cf3ae4',
  '0xa224935d47e2160ceda9f68479f039036b3dc7ab',
  '0x84a9e0c0c3ffa1f460862c1e97521e5cdd428cad',
  '0x9fa2ac1ac343fb9066d7812f2716eec50666814a',
  '0xddf3c8fe2161fbc1ca5d6f534788ca7e84f3499d',
  '0xc791f86f864cf0b7c519e6579b48b5f9351dff37',
  '0xf246d86db4c1ac43e1ddbfe55e4d61d1e3b324e9',
  '0xc8790e75dc53f30dbf8cb8066c13796ec2e18768',
  '0x1db5fa69e451cb26a3ce593bd81321c752983c96',
  '0x572ae711b8d89252d61fc1ec5701179ae6a6992c',
  '0xc6142e98b9187a9f18b171e0f2463a2e581ff8ca',
  '0xc5e7184d2807b21726d67dd05b6c3011f9c5dca5',
  '0xee155d8c8390de7ad4071726e50a546cb22c9961',
  '0xb7973c6d5209b1bf5c198789830b67d5fe340dad',
  '0x401f0b1520c3033b6e55981a76ab55ba532ed242',
  '0x35da61143072716e9ca1dc688e9b04145314e8d1',
  '0x6893593c695d23f002f9278fa75ae1367ce78d96',
  '0x203b2164e7bbb64d87f26a5434d92c1f345fc3bf',
  '0x3329a6f7a7600c10d8c86b73d87e51ad992170b4',
  '0x80a3df6a72e0ee265a0c471f6bdb1284305a8666',
  '0xea2c15b73e07bdd59caec75c08f675fd4cb04229',
  '0x49bde4292f81d7f7e28ad4011d36cce7f307d4bc',
  '0xddd83d778d4ad80877db5a5d4664b9bdaeb33e71',
  '0xcdb5ab079ef474af9230d2f7b3b5a1c6f61d2006',
  '0x8379636fe689cd9bbf71bc19cc58c6a7f5ef06bc',
  '0x3862903859ea9b1ce6804823bd9ca7a249afebb3',
  '0x338f8adbaefe63cb4526f693c586c26d77a6dcd9',
  '0xa5b2be3b0967e7c95bec665c502df2a731806a00',
  '0xd64c49b417c0bf4ef5eb7f80e9da3c46eb64a151',
  '0x0aa350fb487f75d4f5d6ed920a5ae0923ded06e1',
  '0x984572bbe56c9ee793c9b5520a270f23a3ee79e7',
  '0x020a1bbeb60e58dcbfa6901f082bdd10269ed51b',
  '0x1750a0511c653bffc27a2a52f0e05d913469098a',
  '0xccb4e85f2c81566d85a74efbccb0a0bca3b7e988',
  '0x1005d5a881cea9e4d945f542a99b202d79a5a10f',
  '0xeeb4de2fb9bad3e989f6312d19344a1bc9062c81',
  '0x0bb7e19e885279594f8095cad3b6c43daf1f5672',
  '0x88f07e188d1c66bc9b567700e874160f82ed06fe',
  '0x108b7bcf21a9f69467d65e814894b10c88ce8b05',
  '0x3b11cc193ba3ab9c2a0ed9eda03a4d795c766262',
  '0x3aa8ac0e6c1fb9cbb733565de16cdc5a676bcb04',
  '0x8206cd73414a93f17e6e0d9deb215612210642a1',
  '0xe74ef21d7ea510b11e2e969bf15c42375e457651',
  '0x8b93910594e2a09c30d7e97883f6d35d8772801d',
  '0x314de30d89b436d50058d969b30fa6766b3bc659',
  '0x821d02ff01054daa7372f6f1549eed27e97f41b5',
  '0x7a3f7987336804e56e2b2528028573ac4a20b990',
  '0xa7a1fe3c4e690de312b3ae911b1fd9f8e0dc79f4',
  '0xb9653e6727ff3ad4775cea60ce39dd91e69f6216',
  '0x278f434d0e37bd3ca0974b6d2c52e9d6f6d31b81',
  '0x2c941171bd2a7aeda7c2767c438dff36eaafdafc',
  '0x4f3b2a67ae7e6ae8bd06c86b591cc05992b2ab5a',
  '0x0dc350b7a1de51c581899312070ff1c11aa5245b',
  '0xa4b89c8d5b48093d64d9b652c9da1b90bc45b232',
  '0xa37f664fe3a42faf1e69cdb0911556e6f8c21f3c',
  '0xc3623db4857b7b5820fdd37199f3cb6588343902',
  '0x4c48acfaa438190661ad2f697d88a40c9634bcf0',
  '0xacdd5528c1c92b57045041b5278efa06cdade4d8',
  '0xfe362f889a2c843708daf7d32ed70ec6188a3a47',
  '0x2e27ad425fac3b8a25388bb59d086dcc70a3bb8a',
  '0x559b9a961f8da49d578d3dd7899612177dddfa6e',
  '0x44fc2834cdab3d22e885ef26ce1bcbe50c163ccf',
  '0x0b7dc67a6ecf6bc0388409ddde919aafcf0e0ff7',
  '0xf422dfaccf6eb15bb9f7798f9655f18799a35b1e',
  '0xec70538beac744eec5edec4b329205a4b29ba8ae',
  '0x8a1322ad3bfb3a127fc9295c94ea7a26963f85b8',
  '0x545600fa318f1e717756ff461cf0e7e0ecff08e3',
  '0x8b93910594e2a09c30d7e97883f6d35d8772801d'
];

const potentialMigrateAccounts = [
  '0x1d002965923ba11b4d56030d2cfd6ee30325a944',
  '0x16f3fc1e4ba9d70f47387b902fa5d21020b5c6b5',
  '0x97facc99b70e3d4566bc5ecfd3c570e5c484315e',
  '0x106a69f7721503114785d36866e5d37d2befc549',
  '0xc87d6fd2b03554bca205aac771ab67a041ee8902',
  '0x3519ee8f62169cb9a5fd1f33a30e1cd9652f5ec1',
  '0x9495c18e1b7e0b026f8eef3d087d9822c2b70da0',
  '0x60c32eec3c9ae00a3466dbee02db4634453a9b3b',
  '0x226327a7a2b8a7b6afcd560bf7aae90b4ac7cba9',
  '0xfb42a940d1ab79f4e53345fa4cc8629cb84ad2e0',
  '0x371dd0a9a5dd2e8240a8454ee2a1514ca0a21132',
  '0xa0d6460b35599cc20c73fe3500a9c4a95097ea6d',
  '0xc074887d140e276a8b892222f925440eaf3ff40b',
  '0x23292e9ba8434e59e6bac1907ba7425211c4de27',
  '0x6c7ea81bb46ec44720af326a25df1dde93bc4b87',
  '0x18e10f83e1102639ef8a4185b30d5366a2252be5',
  '0xe08685e767fe4654cc97500ab2d008062b69d19d',
  '0xd01d7d004dc1c37f01115f9d8c9b1e668cfcac9e',
  '0xda71e42aa0ecfa65072eb54da294d690d02c5c37',
  '0x854ce16536cc41a0593a754f88a3eaf14eee9938',
  '0x0079ce80043edc3325598e4a3b6293ab779bf174',
  '0xebb2ca5d1b22f5f39e386066c5fd36171d3cd536',
  '0xfebe62b068eb5e9667c58236c23c88a8efb306d2',
  '0x2fc9896cb056cd3f28716ada06e509a1c8fed40f',
  '0x4229a48a1c3d0526a5ff78a376f33e2d8c3ab5a3',
  '0x3637d7f6041d73917017e5d3e2259473215ecf6f',
  '0x838ce16371127f8c30cdc7d854d8043ac7d40dc3',
  '0x336bfa87e446267fbc2c9dab2951e18181e269ea',
  '0xdc42911845e5111b49b889910b0ad5f3939320c4',
  '0xb124c2e19b7de50db658e899d5ecf0a88dc6d99c',
  '0xbd0e8a1011af627e556f2ce595665aa5b78adcb5',
  '0xbe5996aefcb9564f6f8b7054dda23a9bc156285a',
  '0xc3f3999f8df40474a9f9fe8403837d018778c80d',
  '0xbe3e45c2b691b3b8fdce154242d790a05c4e5507',
  '0x70762806a813acacb4ba8790e26f53a131c9d0bd',
  '0x37ab8f80e54fb54625e16c431f0f323024cf3ae4',
  '0x9125c8f8876494dabe0c4f0f911031ac1bf6696a',
  '0xa224935d47e2160ceda9f68479f039036b3dc7ab',
  '0x84a9e0c0c3ffa1f460862c1e97521e5cdd428cad',
  '0xe9abf508d93875d7065633717dca1bed48e67165',
  '0x9fa2ac1ac343fb9066d7812f2716eec50666814a',
  '0xb462fb0098f104e88837a46e5f4fdfb5ebff7d96',
  '0xddf3c8fe2161fbc1ca5d6f534788ca7e84f3499d',
  '0xc791f86f864cf0b7c519e6579b48b5f9351dff37',
  '0xf246d86db4c1ac43e1ddbfe55e4d61d1e3b324e9',
  '0x69df3681df7081abb72e0adf097a6bf9664d3286',
  '0xc8790e75dc53f30dbf8cb8066c13796ec2e18768',
  '0x1db5fa69e451cb26a3ce593bd81321c752983c96',
  '0x572ae711b8d89252d61fc1ec5701179ae6a6992c',
  '0xdbae96e97d00256a09322e1c49f062cb8bebb0f0',
  '0xc6142e98b9187a9f18b171e0f2463a2e581ff8ca',
  '0xc5e7184d2807b21726d67dd05b6c3011f9c5dca5',
  '0xee155d8c8390de7ad4071726e50a546cb22c9961',
  '0xb7973c6d5209b1bf5c198789830b67d5fe340dad',
  '0x401f0b1520c3033b6e55981a76ab55ba532ed242',
  '0x44e8656eb073d58da666217009f2c9591682a4a0',
  '0x35da61143072716e9ca1dc688e9b04145314e8d1',
  '0x6893593c695d23f002f9278fa75ae1367ce78d96',
  '0x203b2164e7bbb64d87f26a5434d92c1f345fc3bf',
  '0x3329a6f7a7600c10d8c86b73d87e51ad992170b4',
  '0x80a3df6a72e0ee265a0c471f6bdb1284305a8666',
  '0xea2c15b73e07bdd59caec75c08f675fd4cb04229',
  '0x49bde4292f81d7f7e28ad4011d36cce7f307d4bc',
  '0xaf4e482294b2e4a7a24b06cd072e62f095a9a5bc',
  '0xddd83d778d4ad80877db5a5d4664b9bdaeb33e71',
  '0xcdb5ab079ef474af9230d2f7b3b5a1c6f61d2006',
  '0x04e34e0c1009b6d1dc2e3f4b5ff63020bdb07316',
  '0x8379636fe689cd9bbf71bc19cc58c6a7f5ef06bc',
  '0x34bfa9762778a9d3bc7f15ae1fff4dcbc24e48f5',
  '0x3862903859ea9b1ce6804823bd9ca7a249afebb3',
  '0x338f8adbaefe63cb4526f693c586c26d77a6dcd9',
  '0xa5b2be3b0967e7c95bec665c502df2a731806a00',
  '0xd64c49b417c0bf4ef5eb7f80e9da3c46eb64a151',
  '0x593a4a1aad8584487a01f7917824ceed09be2fb3',
  '0x0aa350fb487f75d4f5d6ed920a5ae0923ded06e1',
  '0x984572bbe56c9ee793c9b5520a270f23a3ee79e7',
  '0x020a1bbeb60e58dcbfa6901f082bdd10269ed51b',
  '0xa26bc7e6cdfe1d6e254e962a87d7fcb6941b6060',
  '0xe5546ea6535859c5d16373ecabde6de89fb2a4ce',
  '0x1750a0511c653bffc27a2a52f0e05d913469098a',
  '0xf2a53b53f13bfcb2c791c34e4b30348341d2a39d',
  '0xccb4e85f2c81566d85a74efbccb0a0bca3b7e988',
  '0x1005d5a881cea9e4d945f542a99b202d79a5a10f',
  '0xe0db71d26651bbcef473e467bc3f0e125d3cd4cc',
  '0x7ecb9f45c167ac9724382d29b1b3f20bf550bbec',
  '0xc2cf6afb380aa27a4484e14225b6d40b56543ea2',
  '0x887c3599c4826f7b3cde82003b894430f27d5b92',
  '0xeb959caad3bb6e28ba3d9312a8a7ce745767249d',
  '0x92989eb906d40c6385c9982b08c5953cbf763ab2',
  '0x5115c67f5621440fd8413cdad36fdf89b8ac4c01',
  '0xeeb4de2fb9bad3e989f6312d19344a1bc9062c81',
  '0x6e0e75b64010da83ba46a18e4cfd7becc23401ba',
  '0xd1e550c9da2cb74ccf3ac6dd9a49d1b51b7a0a83',
  '0xbacb31bce653584bd8c8ead07fa8f2eb14345294',
  '0x0bb7e19e885279594f8095cad3b6c43daf1f5672',
  '0x8740d9ec65b40be5ebb84bd22607e81260fe3a3a',
  '0x88f07e188d1c66bc9b567700e874160f82ed06fe',
  '0x0752adfe7c42d89bf2fb3c22ffa18b7d0871c807',
  '0x24244ef4839fda2084df4b7c0e4db4d806819cf3',
  '0x2bc87addae195da271c2cb6f773cee647aeefa60',
  '0x108b7bcf21a9f69467d65e814894b10c88ce8b05',
  '0x3b11cc193ba3ab9c2a0ed9eda03a4d795c766262',
  '0x3aa8ac0e6c1fb9cbb733565de16cdc5a676bcb04',
  '0x8206cd73414a93f17e6e0d9deb215612210642a1',
  '0xe74ef21d7ea510b11e2e969bf15c42375e457651',
  '0x8b93910594e2a09c30d7e97883f6d35d8772801d',
  '0x314de30d89b436d50058d969b30fa6766b3bc659',
  '0x821d02ff01054daa7372f6f1549eed27e97f41b5',
  '0x7a3f7987336804e56e2b2528028573ac4a20b990',
  '0xa7a1fe3c4e690de312b3ae911b1fd9f8e0dc79f4',
  '0xb9653e6727ff3ad4775cea60ce39dd91e69f6216',
  '0x278f434d0e37bd3ca0974b6d2c52e9d6f6d31b81',
  '0x907d04a0d526dfe5c9fb73d498be838ba095ddc4',
  '0x9e1d02d853a19c7e476ced1c7c7b881d53176822',
  '0x2c941171bd2a7aeda7c2767c438dff36eaafdafc',
  '0x4f3b2a67ae7e6ae8bd06c86b591cc05992b2ab5a',
  '0x887C3599c4826F7b3cDe82003b894430F27d5b92',
  '0x0dc350b7a1de51c581899312070ff1c11aa5245b',
  '0xa4b89c8d5b48093d64d9b652c9da1b90bc45b232',
  '0xa37f664fe3a42faf1e69cdb0911556e6f8c21f3c',
  '0xc3623db4857b7b5820fdd37199f3cb6588343902',
  '0x4c48acfaa438190661ad2f697d88a40c9634bcf0',
  '0xacdd5528c1c92b57045041b5278efa06cdade4d8',
  '0xfe362f889a2c843708daf7d32ed70ec6188a3a47',
  '0x2e27ad425fac3b8a25388bb59d086dcc70a3bb8a',
  '0x559b9a961f8da49d578d3dd7899612177dddfa6e',
  '0x44fc2834cdab3d22e885ef26ce1bcbe50c163ccf',
  '0x0b7dc67a6ecf6bc0388409ddde919aafcf0e0ff7',
  '0xf422dfaccf6eb15bb9f7798f9655f18799a35b1e',
  '0xec70538beac744eec5edec4b329205a4b29ba8ae',
  '0x8a1322ad3bfb3a127fc9295c94ea7a26963f85b8',
  '0x545600fa318f1e717756ff461cf0e7e0ecff08e3',
  '0x8b93910594e2a09c30d7e97883f6d35d8772801d'
];
