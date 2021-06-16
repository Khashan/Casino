require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const fs = require('fs');
const privateKey = fs.readFileSync(".secret").toString().trim();
module.exports = {
  gasReporter: {
    currency: 'CAD',
    gasPrice: 1,
    coinmarketcap: "4c9f2d2f-ca8f-4f11-9f73-41fb621037a6",
    enabled: true
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    testMatic: {
      url: "https://rpc-mumbai.maticvigil.com",
      chainId: 80001
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.6.5",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
}