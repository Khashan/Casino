const { BigNumber } = require('@ethersproject/bignumber');
const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai");
const { ethers } = require("hardhat");
//await time.advanceBlockTo('170');

describe("Lottery", function () {

    before(async function () {
        [this.owner, this.creator, this.user, this.user2, this.treasury] = await ethers.getSigners();

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");

        this.token = await ERC20Mock.deploy("Token", "TT", this.owner.address, 100);
        this.usdt = await ERC20Mock.deploy("Currency", "USDT", this.owner.address, 0);

        const Random = await ethers.getContractFactory("RandomizerMockCasino");
        const random = await Random.deploy();

        const Casino = await ethers.getContractFactory("Casino");
        this.casino = await Casino.deploy(this.usdt.address, random.address, this.treasury.address);

        random.transferOwnership(this.casino.address);

        this.Lottery = await ethers.getContractFactory("Lottery");
        const lottery = await this.Lottery.deploy();

        const LotteryPhase = await ethers.getContractFactory("LotteryPhase");
        this.lotteryPhase = await LotteryPhase.deploy();

        const Database = await ethers.getContractFactory("DatabaseLottery");
        this.database = await Database.deploy();

        const Factory = await ethers.getContractFactory("FactoryLottery");
        this.factory = await Factory.deploy(this.casino.address, lottery.address, this.lotteryPhase.address, this.database.address, 100);

        await this.casino.connect(this.owner).setFactory(this.factory.address, true);

        await this.token.mint(this.creator.address, 100);
        await this.usdt.mint(this.creator.address, 100000);

        await this.token.mint(this.user.address, 100);
        await this.usdt.mint(this.user.address, 1000000);

        await this.token.mint(this.user2.address, 100);
        await this.usdt.mint(this.user2.address, 1000000);

        await this.usdt.connect(this.user).approve(this.casino.address, ethers.constants.MaxUint256);
        await this.usdt.connect(this.user2).approve(this.casino.address, ethers.constants.MaxUint256);

    });

    describe("General", function () {
        it("Creating Lottery with not enough initial pool", async function () {
            await expectRevert.unspecified(this.factory.connect(this.owner).createLottery(this.token.address, 0, 0, 0));
            await expectRevert.unspecified(this.factory.connect(this.user).createLottery(this.token.address, 0, 0, 0));

            await expectRevert.unspecified(this.factory.connect(this.owner).createLottery(this.token.address, 0, 1000, 0));
            await expectRevert.unspecified(this.factory.connect(this.user).createLottery(this.token.address, 0, 1000, 0));
        });
    });

    describe("Official", function () {

        const INIT_POOL = 50;
        const TICKET_COST = 10;
        var official_lottery;


        it("Create Official", async function () {
            await this.token.connect(this.owner).approve(this.factory.address, INIT_POOL);
            await this.factory.connect(this.owner).createLottery(this.token.address, TICKET_COST, INIT_POOL, 0);

            const lotteries = await this.factory.getCreatorLotteries(this.owner.address);
            official_lottery = this.Lottery.attach(lotteries[0]);


            await this.token.connect(this.user).approve(official_lottery.address, ethers.constants.MaxUint256);
            await this.token.connect(this.user2).approve(official_lottery.address, ethers.constants.MaxUint256);

            await expectRevert.unspecified(official_lottery.connect(this.owner).setDistribution(25, 25, 25, 25));

            expect(lotteries.length).to.not.equal(0);
            expect(await official_lottery.gameCost()).to.equal(TICKET_COST);
            expect(await official_lottery.currentPhase()).to.equal(0);
            expect(await official_lottery.owner()).to.equal(this.owner.address);
            expect(await official_lottery.creator()).to.equal(this.owner.address);

            expect(await official_lottery.isOfficial()).to.equal(true);
            expect(await this.token.balanceOf(official_lottery.address)).to.equal(INIT_POOL);
        })

        it("Init Phase", async function () {
            await expectRevert.unspecified(official_lottery.connect(this.user).play(1));
            await expectRevert.unspecified(official_lottery.connect(this.user).claim());
            await expectRevert.unspecified(official_lottery.connect(this.user).changePhase());

            await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(0)).toNumber()])
            await official_lottery.changePhase();

            expect(await official_lottery.currentPhase()).to.equal(1);
        });

        it("Starting Phase", async function () {
            await expectRevert.unspecified(official_lottery.connect(this.user).play(1));
            await expectRevert.unspecified(official_lottery.connect(this.user).claim());
            await expectRevert.unspecified(official_lottery.connect(this.user).changePhase());

            await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(1)).toNumber()])

            await official_lottery.connect(this.user).play(1);
            expect((await this.token.balanceOf(this.user.address))).is.equal(100 - TICKET_COST);

            expect((await official_lottery.getUserTickets(this.user.address)).length).is.not.equal(0);
        })

        it("Open Phase", async function () {
            await official_lottery.connect(this.user).play(9);
            await expectRevert.unspecified(official_lottery.connect(this.user).play(1));
            await expectRevert.unspecified(official_lottery.connect(this.user2).play(11));
            await expectRevert.unspecified(official_lottery.connect(this.user).claim());
            await expectRevert.unspecified(official_lottery.connect(this.user).changePhase());

            await official_lottery.connect(this.user2).play(2);

            expect((await official_lottery.getUserTickets(this.user.address)).length).is.equal(10);
            expect((await official_lottery.getUserTickets(this.user2.address)).length).is.equal(2);

            await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(2)).toNumber()])
        })

        it("Close Phase", async function () {
            await expectRevert.unspecified(official_lottery.connect(this.user2).play(1));

            let user1Reward = (await official_lottery.getTotalWonByUser(this.user.address)).toNumber();
            let user2Reward = (await official_lottery.getTotalWonByUser(this.user2.address)).toNumber();

            console.log("User 1");
            if (user1Reward == 0) {
                await expectRevert.unspecified(official_lottery.connect(this.user).claim());
            }
            else {
                let userToken = await this.token.balanceOf(this.user.address);
                await official_lottery.connect(this.user).claim();
                expect(await this.token.balanceOf(this.user.address)).is.equal(userToken.add(user1Reward));
            }

            console.log("User 2");
            if (user2Reward == 0) {
                await expectRevert.unspecified(official_lottery.connect(this.user2).claim());
            }
            else {
                let user2Token = await this.token.balanceOf(this.user2.address);
                await official_lottery.connect(this.user2).claim();
                expect(await this.token.balanceOf(this.user2.address)).is.equal(user2Token.add(user2Reward));
            }


            if ((await official_lottery.currentPhase()) != 3) {
                await official_lottery.changePhase();
            }
        })

        it("Next Official Lottery", async function () {
            var nextLottery = this.Lottery.attach(await this.factory.lotteries(0));

            expect(await this.database.oldLottery(0)).is.equal(official_lottery.address);

            expect(nextLottery.address).is.not.equal(official_lottery.address);
            expect(await nextLottery.currentPhase()).to.equal(0);
            console.log("Lottery: " + (await this.token.balanceOf(nextLottery.address)).toNumber());
            expect(await this.token.balanceOf(nextLottery.address)).to.not.equal(0);
            expect(await nextLottery.owner()).to.equal(this.owner.address);
            expect(await nextLottery.creator()).to.equal(this.owner.address);
            expect(await nextLottery.gameCost()).to.equal(TICKET_COST);
        });

        describe("Community", function () {

            var community_limited;
            var community_unlimited;
            const INIT_POOL = 50;
            const TICKET_COST = 10;

            it("Creating Lottery Unlimited", async function () {
                await this.usdt.connect(this.user).approve(this.factory.address, INIT_POOL);

                await expectRevert.unspecified(this.factory.connect(this.user).createLottery(this.usdt.address, TICKET_COST, INIT_POOL, 0));

                await this.casino.connect(this.user).buyToken(100);
                await this.factory.connect(this.user).createLottery(this.usdt.address, TICKET_COST, INIT_POOL, 0);

                const lotteries = await this.factory.getCreatorLotteries(this.user.address);
                community_unlimited = this.Lottery.attach(lotteries[0]);

                expect(await community_unlimited.owner()).is.equal(this.owner.address);
            });


            it("Creating Lottery limited", async function () {
                await this.casino.connect(this.user2).buyToken(100);
                await this.usdt.connect(this.user2).approve(this.factory.address, INIT_POOL);
                await this.factory.connect(this.user2).createLottery(this.usdt.address, TICKET_COST, INIT_POOL, 5);

                const lotteries = await this.factory.getCreatorLotteries(this.user2.address);
                community_limited = this.Lottery.attach(lotteries[0]);

                expect(await community_limited.owner()).is.equal(this.owner.address);
            });

            it("Manul Starts with no distribution", async function () {
                await expectRevert.unspecified(community_limited.connect(this.owner).starts());
                await expectRevert.unspecified(community_limited.connect(this.user).starts());
                await expectRevert.unspecified(community_limited.connect(this.user2).starts());

                await expectRevert.unspecified(community_unlimited.connect(this.owner).starts());
                await expectRevert.unspecified(community_unlimited.connect(this.user2).starts());
                await expectRevert.unspecified(community_unlimited.connect(this.user).starts());
            })

            it("Assign Distribution", async function () {
                await expectRevert.unspecified(community_unlimited.connect(this.user).setDistribution(10, 0, 0, 0));
                await expectRevert.unspecified(community_unlimited.connect(this.user).setDistribution(9000, 500, 1, 0));

                community_unlimited.connect(this.user).setDistribution(2000, 1000, 500, 6000)
                community_limited.connect(this.user2).setDistribution(2000, 1000, 500, 6000)

                let distribution = await community_limited.rewardsDistribution();
                expect(distribution.tier1).is.equal(2000);
                expect(distribution.tier2).is.equal(1000);
                expect(distribution.tier3).is.equal(500);
                expect(distribution.creator).is.equal(6000);
            })

            it("Manual Start - With Distribution", async function () {

                await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(0)).toNumber()])
                await expectRevert.unspecified(community_unlimited.connect(this.owner).changePhase());

                await community_limited.connect(this.user2).starts();
                await community_unlimited.connect(this.user).starts();

                expect(await community_unlimited.currentPhase()).is.equal(1);
                expect(await community_limited.currentPhase()).is.equal(1);
                await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(1)).toNumber()])
            })

            it("Buy Tickets (For limited lottery)", async function () {
                await this.usdt.connect(this.user).approve(community_limited.address, ethers.constants.MaxUint256);
                await this.usdt.connect(this.user2).approve(community_limited.address, ethers.constants.MaxUint256);
                await this.usdt.connect(this.owner).approve(community_limited.address, ethers.constants.MaxUint256);

                await this.usdt.connect(this.user).approve(community_unlimited.address, ethers.constants.MaxUint256);
                await this.usdt.connect(this.user2).approve(community_unlimited.address, ethers.constants.MaxUint256);
                await this.usdt.connect(this.owner).approve(community_unlimited.address, ethers.constants.MaxUint256);

                await community_limited.connect(this.user).play(4);

                await expectRevert.unspecified(community_limited.connect(this.user).play(2))
                await expectRevert.unspecified(community_limited.connect(this.owner).play(4))

                await this.usdt.mint(this.owner.address, 100000);
                await expectRevert.unspecified(community_limited.connect(this.owner).play(6))

                await community_limited.connect(this.user).play(1);
                await community_limited.connect(this.owner).play(5);

                await community_unlimited.connect(this.user).play(10);
                await community_unlimited.connect(this.user2).play(10);
                await community_unlimited.connect(this.owner).play(10);

                await network.provider.send("evm_increaseTime", [(await this.lotteryPhase.getPhaseTimer(2)).toNumber()])
            })

            it("Close", async function () {
                await community_unlimited.changePhase();
                await community_limited.changePhase();

                await expectRevert.unspecified(this.factory.lotteries(2));

                expect((await this.factory.getCreatorLotteries(this.user)).length).is.equal(1);
                expect((await this.factory.getCreatorLotteries(this.user2)).length).is.equal(1);
            })
        });
    })
})
