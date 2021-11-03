// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Greeter = await hre.ethers.getContractFactory("Greeter");
  const greeter = await Greeter.deploy("Hello, Hardhat!");

  await greeter.deployed();

  console.log("Greeter deployed to:", greeter.address);

  const MasterChefv1 = await hre.ethers.getContractFactory("MasterChefV1");
  const masterChef = await MasterChefv1.deploy("Hello, Hardhat!");
 
  const WEAVE_ADDRESS = ""; // .
  const BUSD_ADDRESS = "";  // -- Addrrsses
  const DEV_ADDRESS = "";   // .
  const WEAVE_PER_BLOCK = 0; // 0.01 or 0.1 Weave Tokens according to tokenomics
  const START_BLOCK_NUMBER = 0 //Block number
  const BONUS_END_BLOCK = 0 // Block number
  const ALOCATION_POINT = 0 // It is usually 1000

  await masterChef.deployed(WEAVE_ADDRESS,BUSD_ADDRESS,DEV_ADDRESS,WEAVE_PER_BLOCK,START_BLOCK_NUMBER,BONUS_END_BLOCK,ALOCATION_POINT);

  console.log("MasterChefv1 Contract deployed to:", masterChef.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
