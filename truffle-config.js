module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "5777",
      gas: 8000000, 
      gasPrice: 2000000000, // 2 Gwei, reflecting current low gas prices
      evmVersion: "london" // Explicitly set EVM version
    }
  },
  compilers: {
    solc: {
      version: "0.8.24",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "london"
      }
    }
  },
  mocha: {
    timeout: 100000
  }
};