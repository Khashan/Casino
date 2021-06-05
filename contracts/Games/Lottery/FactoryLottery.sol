pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Lottery.sol";
import "./LotteryPhase.sol";
import "../../Databases/DatabaseLottery.sol";

contract FactoryLottery is IFactoryLottery, Ownable, Clones {
    Lottery[] lotteries;
    LotteryPhase lotteryPhase;
    ICasino casino;
    uint256 treasuryBPSCommunity = 500;

    mapping(address => bool) indexLotteries;

    uint256 creationCost;
    Lottery masterLottery;
    DatabaseLottery database;

    constructor(
        ICasino _casino,
        Lottery _masterLottery,
        LotteryPhase _lotteryPhase,
        DatabaseLottery _database,
        uint256 _creationCost
    ) {
        creationCost = _creationCost;
        masterLottery = _masterLottery;
        lotteryPhase = _lotteryPhase;
        database = _database;
        casino = _casino;
    }

    function createLottery(
        IERC20 _lpToken,
        uint256 _gameCost,
        uint256 _initPool,
        uint256 _maxTicketPerUser
    ) external override {
        require(
            _lpToken.balanceOf(_manager) >= _initPool,
            "Not enough for the initial pool"
        );

        Lottery lottery = Lottery(createClone(masterLottery));
        lottery.init(
            this,
            owner(),
            msg.sender,
            _lpToken,
            _maxTicketPerUser,
            _gameCost,
            _initPool
        );

        indexLottery(lottery);
    }

    function createNextLottery(Lottery oldLottery) external returns (address) {
        require(_isLottery(oldLottery), "Only lottery can call this");
        Lottery lottery = Lottery(createClone(masterLottery));
        lottery.clone(oldLottery);
        indexLottery(lottery);

        return address(lottery);
    }

    function indexLottery(Lottery lottery) internal {
        lotteries.push(lottery);
        indexLotteries[lottery] = lotteries.length - 1;
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
    }

    function _isLottery(address lotteryAddress) internal view returns (bool) {
        uint256 index = indexLotteries[lotteryAddress];
        return lotteryAddress = lotteries[index];
    }

    function getLotteryIndex(address lotteryAddress)
        external
        view
        override
        returns (uint256)
    {
        return indexLotteries[lotteryAddress];
    }

    function closeLottery() external {
        require(_isLottery(msg.sender), "Only Lottery can call this function");

        uint256 index = getLotteryIndex(msg.sender);
        uint256 length = lotteries.length - 1;
        lotteries[index] = lotteries[length];
        lotteries.pop();

        indexLotteries[msg.sender] = 0;

        database.addLottery(msg.sender);
    }
}
