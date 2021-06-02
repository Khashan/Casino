pragma solidity ^0.8.4;

import "../../libs/Game/Game.sol";
import "./LotteryPhase.sol";

contract Lottery is Game {
    struct UserInfo {
        uint256 ticketTier1;
        uint256 ticketTier2;
        uint256 ticketTier3;
        bool notClaimed;
        uint256[uint16] tickets;
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

    address public lpToken;
    bool public isOfficial;

    uint256 private nextPhase = 0;
    uint8 private currentPhase;
    LotteryPhase private lotteryPhase;

    uint16[] private winnableNumber;
    mapping(uint8 => uint256) private totalWinnersPerTier;
    mapping(uint8 => uint256) private sharesPerTierWin;
    mapping(address => UserInfo) private usersInfo;

    RewardsDistribution public rewardsDistribution;

    function init(
        ICasino _casino,
        address _owner,
        address _manager,
        IERC20 _lpToken,
        LotteryPhase _lotteryPhase,
        uint256 _gameCost,
        uint256 _creationCost,
        uint256 _initPool
    ) external {
        require(
            _lpTokne.balanceOf(_manager) >= _initPool,
            "Not enough for the initial pool"
        );
        require(_initPool != 0, "Initial Pool cannot be 0");

        super._init(_casino, _owner, _manager, _gameCost, _creationCost, false);
        _lpToken.safeTransferFrom(_manager, address(this), amount);
        transferOwnership(_owner);
        gameCost = _gameCost;
        isOfficial = _manager == _owner;

        lpToken = _lpToken;
        lotteryPhase = _lotteryPhase;
        currentPhase = uint8(Phase.INIT);
        winnableNumber = casino.getRandomNumbers(4, 16, 1);

        if (IsOfficial) {
            rewardsDistribution = RewardsDistribution(
                400,
                250,
                150,
                0,
                100,
                50,
                (450 + 250 + 150 + 100 + 50)
            );
            _starts();
        } else {
            rewardsDistribution = RewardsDistirbution(0, 0, 0, 0, 50, 0);
        }
    }

    function getUserTickets(address user)
        external
        view
        returns (uint256[uint16] memory)
    {
        return usersInfo[user].tickets;
    }

    function starts() external onlyCreator {
        require(currentPhase == Phase.Init, "Already Started");
        require(isValidDistribution(), "Invalid distribution");
        _starts();
    }

    function _starts() internal {
        currentPhase = uint8(Phase.STARTED);
        nextPhase = block.timestamp + lotteryPhase.getPhaseTimer(currentPhase);
    }

    function setDistribution(
        uint256 _tier1,
        uint256 _tier2,
        uint256 _tier3,
        uint256 _owner
    ) {
        require(
            !isOfficial,
            "Official Lottery can not change their rewards distribution"
        );

        uint256 total = _tier1 + _tier2 + _tier3 + _owner + 50;
        require(total == 1000, "Distribution is not valid");

        rewardsDistribution = RewardsDistribution(
            _tier1,
            _tier2,
            _tier3,
            _owner,
            50,
            0,
            total
        );
    }

    function isValidDistribution() external view returns (bool) {
        return rewardsDistribution.totalAssigned == 1000;
    }

    function enter(uint256 totalTicket) external {
        if (currentPhase == uint8(Phase.STARTING)) {
            changePhase();
        }

        if (currentPhase == uint8(Phase.OPEN)) {
            uint256 tokenCost = totalTicket.mul(gameCost);
            require(lpToken.balanceOf(msg.sender) >= tokenCost);

            uint256[] memory numbers =
                casino.getRandomNumbers(4 * totalTicket, 16, 1);

            uint256 offset = 0;
            for (uint256 i = 0; i < totalTicket; i++) {
                uint16[] ticket =
                    uint16[](
                        numbers[i + offset],
                        numbers[i + offset],
                        numbers[i + offset],
                        number[i + offset]
                    );

                _verifyWinnableTicket(ticket);
                offset += 3;
            }
        }
    }

    function _verifyWinnableTicket(uint16[] ticket, address ticketOwner)
        internal
    {
        bool[] sameNumber =
            bool[](
                _sameValueAt(0, ticket),
                _sameValueAt(1, ticket),
                _sameValueAt(2, ticket),
                _sameValueAt(3, ticket)
            );

        UserInfo storage userInfo = usersInfo[ticketOwner];
        userInfo.tickets.push(ticket);

        if (ticket == winnableTicket) {
            totalWinnersPerTier[1]++;
            userInfo.ticketTier1++;
            userInfo.notClaimed = true;
        } else if (
            (sameNumber[0] && sameNumber[1] && sameNumber[2]) ||
            (sameNumber[1] && sameNumber[2] && sameNumber[3])
        ) {
            totalWinnersPerTier[2]++;
            userInfo.ticketTier2++;
            userInfo.notClaimed = true;
        } else if (
            (sameNumber[0] && sameNumber[1]) ||
            (sameNumber[1] && sameNumber[2]) ||
            (sameNumber[2] && sameNumber[3])
        ) {
            totalWinnersPerTier[3]++;
            userInfo.ticketTier3++;
            userInfo.notClaimed = true;
        }

        usersInfo[ticketOwner] = userInfo;
    }

    function claim() external {
        if (currentPhase == uint8(Phase.OPEN)) {
            changePhase();
        }

        UserInfo storage userInfo = usersInfo[msg.sender];

        bool hasWon =
            userInfo.ticketTier1 + userInfo.ticketTier2 + userInfo.ticketTier3 >
                0;

        require(hasWon && !userInfo.claimed, "Invalid state");

        uint256 totalTokenWon = sharesPerTierWin[1].mul(userInfo.ticketTier1);
        totalTokenWon += sharesPerTierWin[2].mul(userInfo.ticketTier2);
        totalTokenWon += sharesPerTierWin[3].mul(userInfo.ticketTier3);

        userInfo.claimed = true;
        usersInfo[msg.sender] = userInfo;

        lpToken.safeTransfer(msg.sender, totalTokenWon);
    }

    function changePhase() public {
        require(currentPhase < uint8(Phase.CLOSING), "Reached the last phase");
        require(nextPhase <= block.timestamp, "Time is not reached");

        nextPhase =
            block.timestamp +
            lotteryPhase.getPhaseTimer(currentPhase + 1);
        currentPhase++;

        if (currentPhase == uint8(Phase.CLOSING)) {
            _end();
        }
    }

    function _end() internal {
        uint256 totalToken = lpToken.balanceOf(address(this));
        sharesPerTierWin[1] = totalToken
            .mul(10000)
            .div(rewardsDistribution.tier1)
            .div(totalWinnersPerTier[1]);
        sharesPerTierWin[2] = totalToken
            .mul(10000)
            .div(rewardsDistribution.tier2)
            .div(totalWinnersPerTier[2]);
        sharesPerTierWin[3] = totalToken
            .mul(10000)
            .div(rewardsDistribution.tier3)
            .div(totalWinnersPerTier[3]);

        //Treasury
        //FEE
    }

    function _sameValueAt(uint8 index, uint16[] numbers)
        internal
        view
        returns (bool)
    {
        return numbers[index] == winnableNumber[index];
    }
}
