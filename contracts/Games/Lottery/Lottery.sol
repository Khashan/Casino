pragma solidity ^0.8.4;

import "../../libs/Game/Game.sol";
import "./LotteryPhase.sol";

contract Lottery is Game {
    address public lpToken;
    bool private isOfficial;

    uint256 nextPhase = 0;
    uint8 private currentPhase;
    LotteryPhase private lotteryPhase;

    mapping(address => uint256) winners;
    uint16[] winnableNumber;

    struct PickedNumber {
        uint16[] combo;
        address[] users;
    }

    struct NumberStorage {
        uint16[] numbers;
    }

    struct NumberIndexer {
        uint256 id;
        bool exists;
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

    RewardsDistribution public rewardsDistribution;
    PickedNumber[] pickedNumbers;
    mapping(NumberStorage => NumberIndexer) indexes;

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
        uint256 tokenCost = totalTicket.mul(gameCost);
        require(lpToken.balanceOf(msg.sender) >= tokenCost);

        uint16[] memory numbers = casino.getRandomNumbers(4, 16, 1);

        NumberStorage memory numberStorage = NumberStorage(numbers);
        NumberIndexer storage indexer = indexes[numberStorage];
        PickedNumber storage pNumber;

        if (indexer.exists) {
            pNumber = pickedNumbers[indexer.id];
        } else {
            indexer.id = pickedNumbers.length();
            indexer.exists = true;
            pNumber = PickedNumber(numbers, []);
            pickedNumbers.push(pickedNumbers);

            indexes[numberStorage] = indexer;
        }

        lpToken.safeTransferFrom(msg.sender, address(this), tokenCost);
        pNumber.users.push(msg.sender);
        pickedNumbers[index.id] = pNumber;

        participants[msg.sender].push(numbers);
    }

    //Will be called by our automatic system, but user can call it if needed.
    function changePhase() external {
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
        winnableNumber = casino.getRandomNumbers(4, 16, 1);
        NumberStorage storage numberStorage = NumberStorage(winnableNumber);
        uint258 totalPool = lpToken.balanceOf(address(this));

        mapping(uint8 => address[]) _winners;

        for (uint256 i; i < pickedNumbers.length; i++) {
            PickedNumber storage pNumber = pickedNumbers[i];
            bool possibility3_1 =
                sameValueAt(0, pNumber.combo) &&
                    sameValueAt(1, pNumber.combo) &&
                    sameValueAt(2, pNumber.combo);
            bool possibility3_2 =
                sameValueAt(1, pNumber.combo) &&
                    sameValueAt(2, pNumber.combo) &&
                    sameValueAt(3, pNumber.combo);

            bool possibility2_1 =
                sameValueAt(0, pNumber.combo) && sameValueAt(1, pNumber.combo);
            bool possibility2_2 =
                sameValueAt(1, pNumber.combo) && sameValueAt(2, pNumber.combo);
            bool possibility2_3 =
                sameValueAt(2, pNumber.combo) && sameValueAt(3, pNumber.combo);

            //[F,T,T,T]
            //[T,T,F,F]
            //[F,F,T,T]
            //[F,T,T,F]
            if (pNumber.combo == winnableNumber) {
                _winners[4] == pNumber.users;
            } else if (possibility3_1 || possibility3_2) {
                _winners[3].push(pNumber.users);
            } else if (possibility2_1 || possibility2_2 || possibility2_3) {
                _winners[2].push(pNumber.users);
            }
        }

        //Sending for top winners

        uint256 tier1Share =
            totalPool.mul(10000).div(rewardsDistribution.tier1).div(
                _winner[4].length
            );

        uint256 tier2Share =
            totalPool.mul(10000).div(rewardsDistribution.tier2).div(
                _winner[3].length
            );

        uint256 tier3Share =
            totalPool.mul(10000).div(rewardsDistribution.tier3).div(
                _winner[2].length
            );

        for (uint256 i = 0; i < _winners[4].length; i++) {
            winners[_winners[4][i]] += tier1Share;
        }
        for (uint256 i = 0; i < _winners[3].length; i++) {
            winners[_winners[3][i]] += tier2Share;
        }
        for (uint256 i = 0; i < _winners[2].length; i++) {
            winners[_winners[2][i]] += tier3Share;
        }
    }

    function sameValueAt(uint8 index, uint16[] numbers)
        internal
        view
        returns (bool)
    {
        return numbers[index] == winnableNumber[index];
    }

    function claim() external {
        if (currentPhase == uint8(Phase.OPEN)) {
            changePhase();
        }

        if (winners[msg.sender] > 0) {
            uint256 claimable = winners[msg.sender];

            require(
                lpToken.balanceOf(address(this)) >= claimable,
                "Not enough token!"
            );

            winners[msg.sender] = 0;
            lpToken.safeTransfer(msg.sender, claimable);
        }
    }
}
