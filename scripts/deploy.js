// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

const argsPath = path.join(path.resolve("./"), "arguments");

async function main() {
  const Market = await hre.ethers.getContractFactory("MarketPlace");
  const market = await Market.deploy();
  await market.deployed();

  console.log(`Market: ${market.address}`);

  const ERC721 = await hre.ethers.getContractFactory("ERC721Royalty");
  const erc721 = await ERC721.deploy("MarketCollection", "MKC");
  await erc721.deployed();

  console.log(`ERC721: ${erc721.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

const saveArguments = (args, subfx) => {
  const pathFile = path.join(
    argsPath,
    subfx ? `${subfx}.js` : path.basename(__filename)
  );
  const data = `module.exports = ${JSON.stringify(args)}`;
  fs.writeFileSync(pathFile, data);
};