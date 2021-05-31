const { expect } = require("chai");

describe("Store", function () {
    before(async function () {
        [this.owner, this.storeOwner, this.user] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("Token");
        const Store = await ethers.getContractFactory("Store");

        this.token = await Token.deploy(200);
        await this.token.deployed()

        this.store = await Store.deploy(addr1.address, this.token.address);
        await this.store.deployed()
    })

    it("Ttd", async function () {
        expect(await this.store.token()).to.equal(this.token.address);
    });
});