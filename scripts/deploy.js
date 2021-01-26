async function main() {

  const [deployer] = await ethers.getSigners();

  const ArbitratorFactory = await ethers.getContractFactory("TestArbitrator");
  const arbitrator = await ArbitratorFactory.deploy();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  console.log(
    "Arbitrator contract address:",
    arbitrator.address
  );
  
  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy(arbitrator.address);

  console.log("Market contract address:", market.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });