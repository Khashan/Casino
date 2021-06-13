pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./LotteryPhase.sol";
import "../../Databases/DatabaseLottery.sol";

import "hardhat/console.sol";

contract FactoryLottery is IFactoryLottery, Ownable {
    using SafeERC20 for IERC20;

    Lottery[] public lotteries;
    LotteryPhase public lotteryPhase;
    ICasino public casino;
    uint256 public treasuryBPSCommunity = 500;

    mapping(address => bool) private validLotteries;
    mapping(address => Lottery[]) private creatorLotteries;

    uint256 public creationCost;
    address masterLottery;
    DatabaseLottery database;

    event LotteryCreate(address indexed factory, address indexed creator);

    modifier isLottery(address target) {
        require(validLotteries[target], "Not a lottery");
        _;
    }

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
    ) external override {
        require(
            _lpToken.balanceOf(msg.sender) >= _initPool,
            "Not enough for the initial pool"
        );

        require(_initPool != 0, "Initial Pool cannot be 0");

        Lottery lottery = Lottery(Clones.clone(masterLottery));
        address lotteryAddr = address(lottery);
        _lpToken.safeTransferFrom(msg.sender, address(this), _initPool);
        _lpToken.transfer(lotteryAddr, _initPool);

        casino.setGame(lottery, true);

        lottery.init(
            this,
            owner(),
            msg.sender,
            _lpToken,
            _maxTicketPerUser,
            _gameCost
        );

        creatorLotteries[msg.sender].push(lottery);
        validLotteries[lotteryAddr] = true;
        emit LotteryCreate(lotteryAddr, msg.sender);
    }

    function createNextLottery(Lottery oldLottery)
        external
        override
        isLottery(address(oldLottery))
        returns (address)
    {
        Lottery lottery = Lottery(Clones.clone(masterLottery));
        casino.setGame(lottery, true);

        lottery.clone(oldLottery);
        return address(lottery);
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
    }

    function closeLottery() external isLottery(msg.sender) {
        //Disable from casino
        casino.setGame(Lottery(msg.sender), false);

        //Delete validator data
        delete validLotteries[msg.sender];

        //Delete from active lotteries
        lotteries[0] = lotteries[lotteries.length - 1];
        lotteries.pop();

        //Add to db
        database.addLottery(Lottery(msg.sender));
    }

    function getCreatorLotteries(address creator)
        external
        view
        override
        returns (Lottery[] memory)
    {
        return creatorLotteries[creator];
    }
}
