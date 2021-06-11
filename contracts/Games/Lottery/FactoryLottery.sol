pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./LotteryPhase.sol";
import "../../Databases/DatabaseLottery.sol";

contract FactoryLottery is IFactoryLottery, Ownable {
    using SafeERC20 for IERC20;

    Lottery[] lotteries;
    LotteryPhase public lotteryPhase;
    ICasino public casino;
    uint256 public treasuryBPSCommunity = 500;

    mapping(address => uint256) indexLotteries;

    uint256 public creationCost;
    address masterLottery;
    DatabaseLottery database;

    constructor(
        ICasino _casino,
        address _masterLottery,
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
    ) external override returns (Lottery lottery) {
        require(
            _lpToken.balanceOf(msg.sender) >= _initPool,
            "Not enough for the initial pool"
        );

        require(_initPool != 0, "Initial Pool cannot be 0");

        lottery = Lottery(Clones.clone(masterLottery));
        _lpToken.safeTransferFrom(msg.sender, address(this), _initPool);
        _lpToken.transfer(address(lottery), _initPool);

        casino.setGame(lottery, true);

        lottery.init(
            this,
            owner(),
            msg.sender,
            _lpToken,
            _maxTicketPerUser,
            _gameCost
        );

        indexLottery(lottery);

        return lottery;
    }

    function createNextLottery(Lottery oldLottery)
        external
        override
        returns (address)
    {
        require(_isLottery(address(oldLottery)), "Only lottery can call this");
        Lottery lottery = Lottery(Clones.clone(masterLottery));
        lottery.clone(oldLottery);
        indexLottery(lottery);

        return address(lottery);
    }

    function indexLottery(Lottery lottery) internal {
        lotteries.push(lottery);
        indexLotteries[address(lottery)] = lotteries.length - 1;
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
    }

    function _isLottery(address lotteryAddress) internal view returns (bool) {
        uint256 index = indexLotteries[lotteryAddress];
        return lotteryAddress == address(lotteries[index]);
    }

    function getLotteryIndex(address lotteryAddress)
        internal
        view
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
        casino.setGame(Lottery(msg.sender), false);

        database.addLottery(Lottery(msg.sender));
    }
}
