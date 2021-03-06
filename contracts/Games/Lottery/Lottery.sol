pragma solidity ^0.8.4;

import "../../libs/Game/Game.sol";
import "./FactoryLottery.sol";
import "./LotteryPhase.sol";

contract Lottery is Game {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum Tiers {TIER1, TIER2, TIER3, TREASURY}

    struct UserInfo {
        mapping(Tiers => uint256) ticketTiers;
        bool notClaimed;
        Ticket[] tickets;
    }

    struct RewardsDistribution {
        uint256 tier1;
        uint256 tier2;
        uint256 tier3;
        uint256 creator;
        uint256 treasury;
        uint256 fee;
        uint256 totalAssigned;
    }

    struct Ticket {
        uint16[4] numbers;
    }

    IERC20 public lpToken;
    bool public isOfficial;
    uint256 public maxTicketPerUser;

    uint256 private nextPhase = 0;
    uint8 public currentPhase;
    RewardsDistribution public rewardsDistribution;

    uint16[4] public winnableNumber;
    mapping(Tiers => uint256) private totalWinnersPerTier;
    mapping(Tiers => uint256) private sharesPerTierWin;
    mapping(address => UserInfo) private usersInfo;

    FactoryLottery public factory;
    LotteryPhase lotteryPhase;

    function clone(Lottery oldLottery) external {
        super._init(
            oldLottery.casino(),
            oldLottery.owner(),
            oldLottery.creator(),
            oldLottery.gameCost(),
            0,
            false
        );

        _initLottery(
            oldLottery.factory(),
            oldLottery.lpToken(),
            oldLottery.maxTicketPerUser()
        );
    }

    function init(
        FactoryLottery _factory,
        address _owner,
        address _creator,
        IERC20 _lpToken,
        uint256 _maxTicketPerUser,
        uint256 _gameCost
    ) public {
        super._init(
            _factory.casino(),
            _owner,
            _creator,
            _gameCost,
            _factory.creationCost(),
            false
        );

        _initLottery(_factory, _lpToken, _maxTicketPerUser);
    }

    function _initLottery(
        FactoryLottery _factory,
        IERC20 _lpToken,
        uint256 _maxTicketPerUser
    ) internal {
        isOfficial = creator == owner;
        factory = _factory;
        lpToken = _lpToken;
        maxTicketPerUser = _maxTicketPerUser;
        lotteryPhase = _factory.lotteryPhase();

        currentPhase = uint8(LotteryPhase.Phase.INIT);
        uint256[] memory randoms = casino.getRandomNumbers(4, 16, 1);

        winnableNumber[0] = uint16(randoms[0]);
        winnableNumber[1] = uint16(randoms[1]);
        winnableNumber[2] = uint16(randoms[2]);
        winnableNumber[3] = uint16(randoms[3]);

        _initDefaultDistribution();
        casino.getDatabaseUser().userCreated(creator);
    }

    function _initDefaultDistribution() internal {
        if (isOfficial) {
            rewardsDistribution = RewardsDistribution(
                4000,
                2500,
                1500,
                0,
                1000,
                500,
                (4500 + 2500 + 1500 + 1000 + 500)
            );
            nextPhase =
                block.timestamp +
                lotteryPhase.getPhaseTimer(currentPhase);
        } else {
            rewardsDistribution = RewardsDistribution(0, 0, 0, 0, 500, 0, 500);
        }
    }

    function getUserTickets(address user)
        external
        view
        returns (Ticket[] memory)
    {
        return usersInfo[user].tickets;
    }

    function starts() external isCreator {
        require(
            currentPhase == uint8(LotteryPhase.Phase.INIT),
            "Already Started"
        );
        require(isValidDistribution(), "Invalid distribution");
        currentPhase = uint8(LotteryPhase.Phase.STARTING);
        nextPhase = block.timestamp + lotteryPhase.getPhaseTimer(currentPhase);
    }

    function setDistribution(
        uint256 _tier1,
        uint256 _tier2,
        uint256 _tier3,
        uint256 _creator
    ) external isCreator {
        require(
            !isOfficial,
            "Official Lottery can not change their rewards distribution"
        );

        uint256 total =
            _tier1 +
                _tier2 +
                _tier3 +
                _creator +
                factory.treasuryBPSCommunity();

        require(total == 10000, "Distribution is not valid");

        rewardsDistribution = RewardsDistribution(
            _tier1,
            _tier2,
            _tier3,
            _creator,
            factory.treasuryBPSCommunity(),
            0,
            total
        );
    }

    function isValidDistribution() public view returns (bool) {
        return rewardsDistribution.totalAssigned == 10000;
    }

    function play(uint256 totalTicket) external override {
        require(totalTicket <= 10, "Too many tickets in one go.");
        require(
            currentPhase != uint8(LotteryPhase.Phase.INIT),
            "Lottery is not done initializing"
        );

        UserInfo storage userInfo = usersInfo[msg.sender];

        if (maxTicketPerUser != 0) {
            require(
                userInfo.tickets.length + totalTicket <= maxTicketPerUser,
                "You have reached the max ticket entries"
            );
        }

        if (currentPhase == uint8(LotteryPhase.Phase.STARTING)) {
            changePhase();
        }

        require(
            currentPhase == uint8(LotteryPhase.Phase.OPEN) &&
                nextPhase > block.timestamp,
            "Lottery is closed"
        );

        uint256 tokenCost = totalTicket.mul(gameCost);
        require(
            lpToken.balanceOf(msg.sender) >= tokenCost,
            "Not enough lpToken"
        );
        lpToken.safeTransferFrom(msg.sender, address(this), tokenCost);

        uint256[] memory numbers =
            casino.getRandomNumbers(4 * totalTicket, 16, 1);

        uint256 offset = 0;
        for (uint256 i = 0; i < totalTicket; i++) {
            Ticket memory ticket =
                Ticket(
                    [
                        uint16(numbers[i + offset]),
                        uint16(numbers[i + 1 + offset]),
                        uint16(numbers[i + 2 + offset]),
                        uint16(numbers[i + 3 + offset])
                    ]
                );

            _verifyWinnableTicket(ticket, msg.sender);
            offset += 3;
        }

        casino.getDatabaseUser().userJoined(msg.sender);
    }

    function _verifyWinnableTicket(Ticket memory ticket, address ticketOwner)
        internal
    {
        UserInfo storage userInfo = usersInfo[ticketOwner];
        userInfo.tickets.push(ticket);

        (bool[3] memory results, bool won) = _fetchResult(ticket.numbers);
        bool notClaimed = userInfo.notClaimed;

        if (won) {
            userInfo.notClaimed = true;
        }

        if (results[0]) {
            totalWinnersPerTier[Tiers.TIER1]++;
            userInfo.ticketTiers[Tiers.TIER1]++;
        } else if (results[1]) {
            totalWinnersPerTier[Tiers.TIER2]++;
            userInfo.ticketTiers[Tiers.TIER2]++;
        } else if (results[2]) {
            totalWinnersPerTier[Tiers.TIER3]++;
            userInfo.ticketTiers[Tiers.TIER3]++;
        }

        if (!notClaimed && userInfo.notClaimed) {
            casino.getDatabaseUser().userWon(msg.sender);
        }
    }

    function claim() external {
        if (currentPhase == uint8(LotteryPhase.Phase.OPEN)) {
            changePhase();
        }

        UserInfo storage userInfo = usersInfo[msg.sender];

        require(userInfo.notClaimed, "Invalid state");

        userInfo.notClaimed = false;

        lpToken.safeTransfer(msg.sender, _getTotalWonByUser(userInfo));
    }

    function getTotalWonByUser(address user) external view returns (uint256) {
        UserInfo storage userInfo = usersInfo[user];

        return
            (!this.isDone())
                ? _estimateTokenWonByUser(userInfo)
                : _getTotalWonByUser(userInfo);
    }

    function _estimateTokenWonByUser(UserInfo storage userInfo)
        internal
        view
        returns (uint256 rewards)
    {
        if (!userInfo.notClaimed) {
            return 0;
        }

        (uint256 tier1, uint256 tier2, uint256 tier3, uint256 treasury) =
            _getDistributionRewards();

        rewards = tier1
            .mul(userInfo.ticketTiers[Tiers.TIER1])
            .add(tier2.mul(userInfo.ticketTiers[Tiers.TIER2]))
            .add(tier3.mul(userInfo.ticketTiers[Tiers.TIER3]));

        return rewards;
    }

    function _getTotalWonByUser(UserInfo storage userInfo)
        internal
        view
        returns (uint256)
    {
        uint256 totalTokenWon =
            sharesPerTierWin[Tiers.TIER1]
                .mul(userInfo.ticketTiers[Tiers.TIER1])
                .add(
                sharesPerTierWin[Tiers.TIER2].mul(
                    userInfo.ticketTiers[Tiers.TIER2]
                )
            )
                .add(
                sharesPerTierWin[Tiers.TIER3].mul(
                    userInfo.ticketTiers[Tiers.TIER3]
                )
            );

        return totalTokenWon;
    }

    function changePhase() public {
        require(nextPhase != 0, "Lottery isn't started");
        require(
            currentPhase < uint8(LotteryPhase.Phase.CLOSING),
            "Reached the last phase"
        );
        require(nextPhase <= block.timestamp, "Time is not reached");

        nextPhase =
            block.timestamp +
            lotteryPhase.getPhaseTimer(currentPhase + 1);

        currentPhase++;

        if (this.isDone()) {
            _end();
        }
    }

    function isDone() external view override returns (bool) {
        return currentPhase == uint8(LotteryPhase.Phase.CLOSING);
    }

    function _end() internal {
        uint256 totalToken = lpToken.balanceOf(address(this));
        _distributeRewards();

        uint256 tokenLeft = totalToken.sub(_getTotalDistributedTokens());

        lpToken.safeTransfer(
            casino.getTreasury(),
            sharesPerTierWin[Tiers.TREASURY]
        );

        if (isOfficial) {
            _prepareNextLottery(tokenLeft);
        } else {
            lpToken.safeTransfer(creator, tokenLeft);
        }

        factory.closeLottery();
    }

    function _distributeRewards() internal {
        (
            sharesPerTierWin[Tiers.TIER1],
            sharesPerTierWin[Tiers.TIER2],
            sharesPerTierWin[Tiers.TIER3],
            sharesPerTierWin[Tiers.TREASURY]
        ) = _getDistributionRewards();
    }

    function _getDistributionRewards()
        internal
        view
        returns (
            uint256 tier1,
            uint256 tier2,
            uint256 tier3,
            uint256 treasury
        )
    {
        uint256 totalToken = lpToken.balanceOf(address(this));

        uint256 totalWinnerTier1 = totalWinnersPerTier[Tiers.TIER1];
        uint256 totalWinnerTier2 = totalWinnersPerTier[Tiers.TIER2];
        uint256 totalWinnerTier3 = totalWinnersPerTier[Tiers.TIER3];

        tier1 = applyBPS(totalToken, rewardsDistribution.tier1).div(
            totalWinnerTier1 != 0 ? totalWinnerTier1 : 1
        );

        tier2 = applyBPS(totalToken, rewardsDistribution.tier2).div(
            totalWinnerTier2 != 0 ? totalWinnerTier2 : 1
        );

        tier3 = applyBPS(totalToken, rewardsDistribution.tier3).div(
            totalWinnerTier3 != 0 ? totalWinnerTier3 : 1
        );

        treasury = applyBPS(totalToken, rewardsDistribution.treasury);

        return (tier1, tier2, tier3, treasury);
    }

    function _getTotalDistributedTokens() internal view returns (uint256) {
        uint256 totalTokenForTier1 =
            sharesPerTierWin[Tiers.TIER1].mul(totalWinnersPerTier[Tiers.TIER1]);
        uint256 totalTokenForTier2 =
            sharesPerTierWin[Tiers.TIER2].mul(totalWinnersPerTier[Tiers.TIER2]);
        uint256 totalTokenForTier3 =
            sharesPerTierWin[Tiers.TIER3].mul(totalWinnersPerTier[Tiers.TIER3]);
        uint256 totalTokenTreasury = sharesPerTierWin[Tiers.TREASURY];

        return
            totalTokenForTier1
                .add(totalTokenForTier2)
                .add(totalTokenForTier3)
                .add(totalTokenTreasury);
    }

    function _prepareNextLottery(uint256 tokenLeft) internal {
        address newLottery = factory.createNextLottery(this);
        lpToken.safeTransfer(newLottery, tokenLeft);
    }

    function _fetchResult(uint16[4] memory numbers)
        internal
        view
        returns (bool[3] memory, bool won)
    {
        bool[4] memory matching =
            [
                numbers[0] == winnableNumber[0],
                numbers[1] == winnableNumber[1],
                numbers[2] == winnableNumber[2],
                numbers[3] == winnableNumber[3]
            ];

        bool[3] memory results =
            [
                (matching[0] && matching[1] && matching[2] && matching[3]),
                ((matching[0] && matching[1] && matching[2]) ||
                    (matching[1] && matching[2] && matching[3])),
                ((matching[0] && matching[1]) ||
                    (matching[1] && matching[2]) ||
                    (matching[2] && matching[3]))
            ];

        return (results, results[0] || results[1] || results[2]);
    }
}
