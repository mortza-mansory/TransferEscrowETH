const Transfer = artifacts.require("Transfer");

contract("Transfer", (accounts) => {
  let instance;

  before(async () => {
    console.log("Accounts:", accounts);
    instance = await Transfer.new({ gas: 6000000 });
        console.log("Contract deployed at:", instance.address);
  });

  it("should deploy and transfer ETH to owner", async () => {
    const sender = accounts[1]; 
    const amount = web3.utils.toWei("1", "ether"); 

    const tx = await instance.sendToOwner({ from: sender, value: amount, gas: 200000 });

    console.log("Transaction Hash:", tx.tx);
    
    console.log("FundsTransferred Event:", {
      event: tx.logs[0].event,
      from: tx.logs[0].args.from,
      to: tx.logs[0].args.to,
      amount: tx.logs[0].args.amount.toString()
    });
    
    assert.equal(tx.logs.length, 1, "Event was not emitted");
    assert.equal(tx.logs[0].event, "FundsTransferred", "Incorrect event name");
    assert.equal(tx.logs[0].args.from, sender, "Incorrect sender address");
    assert.equal(tx.logs[0].args.to, "0x814EabE6C22a4ba2B7658702cd9cB56155DbD34f", "Incorrect owner address");
    assert.equal(tx.logs[0].args.amount.toString(), amount, "Incorrect amount transferred");
  });
});
