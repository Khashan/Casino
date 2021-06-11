const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai");
const { ethers } = require("hardhat");
//await time.advanceBlockTo('170');

describe("Lottery", function () {

    before(async function () {
        [this.owner, this.creator, this.user] = await ethers.getSigners();

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");

        this.token = await ERC20Mock.deploy("Token", "TT", this.owner.address, 100);
        this.fakeT = await ERC20Mock.deploy("FToken", "FT", this.owner.address, 100);
        this.usdt = await ERC20Mock.deploy("Currency", "USDT", this.owner.address, 100);

        const Random = await ethers.getContractFactory("RandomizerMockCasino");
        const random = await Random.deploy();

        const Casino = await ethers.getContractFactory("Casino");
        this.casino = await Casino.deploy(this.usdt.address, random.address);

        random.transferOwnership(this.casino.address);

        const Lottery = await ethers.getContractFactory("Lottery");
        const lottery = await Lottery.deploy();

        const LotteryPhase = await ethers.getContractFactory("LotteryPhase");
        const lotteryPhase = await LotteryPhase.deploy();

        const Database = await ethers.getContractFactory("DatabaseLottery");
        this.database = await Database.deploy();

        const Factory = await ethers.getContractFactory("FactoryLottery");
        this.factory = await Factory.deploy(this.casino.address, lottery.address, lotteryPhase.address, this.database.address, 100);

        this.casino.setFactory(this.factory.address, true, { from: this.owner.address });

        await this.token.mint(this.creator.address, 100);
        await this.fakeT.mint(this.creator.address, 100);
        await this.usdt.mint(this.creator.address, 100);

        await this.token.mint(this.user.address, 100);
        await this.fakeT.mint(this.user.address, 100);
        await this.usdt.mint(this.user.address, 100);
    });

    describe("General", function () {
        it("Creating Lottery with not enough initial pool", async function () {
            await expectRevert.unspecified(this.factory.createLottery(this.token.address, 0, 0, 0, { from: this.owner.address }));
            await expectRevert.unspecified(this.factory.createLottery(this.token.address, 0, 0, 0, { from: this.user.token }));

            await expectRevert.unspecified(this.factory.createLottery(this.token.address, 0, 1000, 0, { from: this.owner.address }));
            await expectRevert.unspecified(this.factory.createLottery(this.token.address, 0, 1000, 0, { from: this.user.token }));
        });
    });

    describe("Official", function () {

        const INIT_POOL = 50;
        const TICKET_COST = 10;


        it("Create Official", async function () {
            this.token.approve(this.factory.address, INIT_POOL, { from: this.owner.address });
            this.official_lottery = await this.factory.createLottery(this.token.address, TICKET_COST, INIT_POOL, 0, { from: this.owner.address });

            //expect(await official_lottery.owner).to.equal(this.owner.address);
            //expect(await official_lottery.creator).to.equal(this.owner.address);

            //expect(await official_lottery.isOfficial).to.equal(true);
            console.log(this.official_lottery.address)
            expect(await this.token.balanceOf(this.official_lottery.address)).to.equal(INIT_POOL);
        })
    });

    describe("Community", function () {

        it("Creating Lottery", async function () {
        });
    });
})
