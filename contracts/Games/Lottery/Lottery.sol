pragma solidity ^0.8.4;

import "../../libs/Game/Game.sol";
import "./FactoryLottery.sol";

contract Lottery is Game {
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
        uint256 owner;
        uint256 treasury;
        uint256 fee;
        uint256 totalAssigned;
    }

    struct Ticket {
        uint16[] numbers;
    }

    IERC20 public lpToken;
    bool public isOfficial;
    uint256 public maxTicketPerUser;

    uint256 private nextPhase = 0;
    uint8 public currentPhase;
    RewardsDistribution public rewardsDistribution;

    uint16[] private winnableNumber;
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
        uint256 _gameCost,
        uint256 _initPool
    ) public {
        super._init(
            _factory.casino(),
            _owner,
            _creator,
            _gameCost,
            _factory.creationCost(),
            false
        );
        require(
            _lpToken.balanceOf(_creator) >= _initPool,
            "Not enough for the initial pool"
        );
        require(_initPool != 0, "Initial Pool cannot be 0");

        _lpToken.safeTransferFrom(_creator, address(this), _initPool);

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
        winnableNumber = uint16[](casino.getRandomNumbers(4, 16, 1));

        _initDefaultDistribution();
    }

    function _initDefaultDistribution() internal {
        if (isOfficial) {
            rewardsDistribution = RewardsDistribution(
                400,
                250,
                150,
                0,
                100,
                50,
                (450 + 250 + 150 + 100 + 50)
            );
            nextPhase =
                block.timestamp +
                lotteryPhase.getPhaseTimer(currentPhase);
        } else {
            rewardsDistribution = RewardsDistribution(0, 0, 0, 0, 50, 0, 50);
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
        currentPhase = uint8(lotteryPhase.Phase.STARTED);
        nextPhase = block.timestamp + lotteryPhase.getPhaseTimer(currentPhase);
    }

    function setDistribution(
        uint256 _tier1,
        uint256 _tier2,
        uint256 _tier3,
        uint256 _owner
    ) external isCreator {
        require(
            !isOfficial,
            "Official Lottery can not change their rewards distribution"
        );

        uint256 total =
            _tier1 + _tier2 + _tier3 + _owner + factory.treasuryBPSCommunity;

        require(total == 10000, "Distribution is not valid");

        rewardsDistribution = RewardsDistribution(
            _tier1,
            _tier2,
            _tier3,
            _owner,
            factory.treasuryBPSCommunity,
            0,
            total
        );
    }

    function isValidDistribution() public view returns (bool) {
        return rewardsDistribution.totalAssigned == 1000;
    }

    function play(uint256 totalTicket) external override returns (bool) {
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

        if (currentPhase == uint8(LotteryPhase.Phase.OPEN)) {
            uint256 tokenCost = totalTicket.mul(gameCost);
            require(lpToken.balanceOf(msg.sender) >= tokenCost);

            uint256[] memory numbers =
                casino.getRandomNumbers(4 * totalTicket, 16, 1);

            uint256 offset = 0;
            for (uint256 i = 0; i < totalTicket; i++) {
                Ticket storage ticket =
                    Ticket(
                        uint16[](
                            numbers[i + offset],
                            numbers[i + offset],
                            numbers[i + offset],
                            numbers[i + offset]
                        )
                    );

                _verifyWinnableTicket(ticket.numbers, msg.sender);
                offset += 3;
            }
        }
    }

    function _verifyWinnableTicket(Ticket storage ticket, address ticketOwner)
        internal
    {
        bool[] memory sameNumber =
            bool[](
                _sameValueAt(0, ticket.numbers),
                _sameValueAt(1, ticket.numbers),
                _sameValueAt(2, ticket.numbers),
                _sameValueAt(3, ticket.numbers)
            );

        UserInfo storage userInfo = usersInfo[ticketOwner];
        userInfo.tickets.push(ticket);

        if (ticket.numbers == winnableNumber) {
            totalWinnersPerTier[Tiers.TIER1]++;
            userInfo.ticketTiers[Tiers.TIER1]++;
            userInfo.notClaimed = true;
        } else if (
            (sameNumber[0] && sameNumber[1] && sameNumber[2]) ||
            (sameNumber[1] && sameNumber[2] && sameNumber[3])
        ) {
            totalWinnersPerTier[Tiers.TIER2]++;
            userInfo.ticketTiers[Tiers.TIER2]++;
            userInfo.notClaimed = true;
        } else if (
            (sameNumber[0] && sameNumber[1]) ||
            (sameNumber[1] && sameNumber[2]) ||
            (sameNumber[2] && sameNumber[3])
        ) {
            totalWinnersPerTier[Tiers.TIER3]++;
            userInfo.ticketTiers[Tiers.TIER3]++;
            userInfo.notClaimed = true;
        }

        usersInfo[ticketOwner] = userInfo;
    }

    function claim() external {
        if (currentPhase == uint8(LotteryPhase.Phase.OPEN)) {
            changePhase();
        }

        UserInfo storage userInfo = usersInfo[msg.sender];
        uint256 totalWon = _getTotalWonByUser(userInfo);

        require(totalWon > 0 && !userInfo.claimed, "Invalid state");

        userInfo.claimed = true;
        usersInfo[msg.sender] = userInfo;

        lpToken.safeTransfer(msg.sender, _getTotalWonByUser());
    }

    function getTotalWonByUser(address user) external view returns (uint256) {
        if (currentPhase != uint8(LotteryPhase.Phase.CLOSING)) {
            return 0;
        }

        UserInfo storage userInfo = usersInfo[user];
        return _getTotalWonByUser(userInfo);
    }

    function _getTotalWonByUser(UserInfo storage userInfo)
        internal
        view
        returns (uint256)
    {
        uint256 totalTokenWon =
            sharesPerTierWin[Tiers.TIER1].mul(
                userInfo.ticketTiers[Tiers.TIER1]
            );

        totalTokenWon.add(
            sharesPerTierWin[Tiers.TIER2].mul(userInfo.ticketTiers[Tiers.TIER2])
        );

        totalTokenWon.add(
            sharesPerTierWin[Tiers.TIER3].mul(userInfo.ticketTiers[Tiers.TIER3])
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

        if (currentPhase == uint8(LotteryPhase.Phase.CLOSING)) {
            _end();
        }
    }

    function isDone() external view returns (bool) {
        return currentPhase == uint8(LotteryPhase.Phase.CLOSING);
    }

    function _end() internal {
        uint256 totalToken = lpToken.balanceOf(address(this));
        _distributeRewards(totalToken);

        uint256 tokenLeft = totalToken.sub(_getTotalDistributedTokens());

        lpToken.safeTransfer(casino.treasury, sharesPerTierWin[Tiers.LOTTERY]);

        if (isOfficial) {
            _prepareNextLottery(tokenLeft);
        } else {
            lpToken.safeTransfer(creator, tokenLeft);
        }

        factory.closeLottery();
    }

    function _distributeRewards(uint256 totalToken) internal {
        sharesPerTierWin[Tiers.TIER1] = applyBPS(
            totalToken,
            rewardsDistribution
                .tier1
        )
            .div(totalWinnersPerTier[Tiers.TIER1]);

        sharesPerTierWin[Tiers.TIER2] = applyBPS(
            totalToken,
            rewardsDistribution
                .tier2
        )
            .div(totalWinnersPerTier[Tiers.TIER2]);

        sharesPerTierWin[Tiers.TIER3] = applyBPS(
            totalToken,
            rewardsDistribution
                .tier3
        )
            .div(totalWinnersPerTier[Tiers.TIER3]);

        sharesPerTierWin[Tiers.TREASURY] = applyBPS(
            totalToken,
            rewardsDistribution.treasury
        );
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
        lpToken.safeTransfer(newLottery, lpToken.balanceof(address(this)));
    }

    function _sameValueAt(uint8 index, uint16[] memory numbers)
        internal
        view
        returns (bool)
    {
        return numbers[index] == winnableNumber[index];
    }
}
