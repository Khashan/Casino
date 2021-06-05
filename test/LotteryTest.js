const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai");
const { ethers } = require("hardhat");
const ERC20Mock = artifacts.require('ERC20Mock');
//await time.advanceBlockTo('170');

describe("Lottery", function () {

    before(async function () {
        [this.owner, this.creator, this.user] = await ethers.getSigners();

        this.token = await ERC20Mock.new("Token", "TT", this.owner, 0);
        this.fakeT = await ERC20Mock.new("FToken", "FT", this.owner, 0);
        this.usdt = await ERC20Mock.new("Currency", "USDT", this.owner, 0);

        const Random = await ethers.getContractFactory("RandomizerMock");
        const random = await Random.deploy();

        const Casino = await ethers.getContractFactory("Casino");
        this.casino = await Casino.deploy(this.usdt, random);

        random.transferOwnership(this.casino);

        const Lottery = await ethers.getContractFactory("Lottery");
        const lottery = await Lottery.deploy();

        const LotteryPhase = await ethers.getContractFactory("LotteryPhase");
        const lotteryPhase = await LotteryPhase.deploy();

        const Database = await ethers.getContractFactory("DatabaseLottery");
        this.database = await Database.deploy();

        const Factory = await ethers.getContractFactory("FactoryLottery");
        this.factory = await Factory.deploy(this.casino, lottery, lotteryPhase, this.database, 100);


        await this.token.mint(this.creator, 100);
        await this.fakeT.mint(this.creator, 100);
        await this.usdt.mint(this.creator, 100);

        await this.token.mint(this.user, 100);
        await this.fakeT.mint(this.user, 100);
        await this.usdt.mint(this.user, 100);
    });

    describe("Official", function () {

        it("Creating Lottery with not enough initial pool", async function () {
            await expectRevert(this.factory.createLottery(this.token, 100, 0, 0));
        });
    });

    describe("Community", function () {

        it("Creating Lottery", async function () {
            const [owner, addr1, addr2] = await ethers.getSigners();

            const Lottery = await ethers.getContractFactory("Lottery");

            const hardhatToken = await Token.deploy();

            // Transfer 50 tokens from owner to addr1
            await hardhatToken.transfer(addr1.address, 50);
            expect(await hardhatToken.balanceOf(addr1.address)).to.equal(50);

            // Transfer 50 tokens from addr1 to addr2
            await hardhatToken.connect(addr1).transfer(addr2.address, 50);
            expect(await hardhatToken.balanceOf(addr2.address)).to.equal(50);
        });
    });
})
