const Transfer = artifacts.require("Transfer");

module.exports = function (deployer) {
  deployer.deploy(Transfer, { gas: 6000000 });
};
