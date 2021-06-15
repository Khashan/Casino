pragma solidity ^0.8.4;

import "../../libs/Factory/IFactoryLottery.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./LotteryPhase.sol";

contract FactoryLottery is IFactoryLottery, Ownable {
    using SafeERC20 for IERC20;

    Lottery[] public lotteries;
    LotteryPhase public lotteryPhase;
    ICasino public casino;
    uint256 public treasuryBPSCommunity = 500;

    uint256 public creationCost;
    address masterLottery;
    IDatabaseGame databaseGame;

    event LotteryCreate(address indexed factory, address indexed creator);

    constructor(
        ICasino _casino,
        address _masterLottery,
        LotteryPhase _lotteryPhase,
        IDatabaseGame _databaseGame,
        uint256 _creationCost
    ) {
        creationCost = _creationCost;
        masterLottery = _masterLottery;
        lotteryPhase = _lotteryPhase;
        databaseGame = _databaseGame;
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

        _onLotteryCreated(lottery);
    }

    function createNextLottery(Lottery oldLottery)
        external
        override
        returns (address)
    {
        (uint256 index, bool found) = getLotteryIndex(oldLottery);
        require(found, "Invalid lottery");

        Lottery lottery = Lottery(Clones.clone(masterLottery));
        casino.setGame(lottery, true);

        lottery.clone(oldLottery);
        _onLotteryCreated(lottery);
        return address(lottery);
    }

    function _onLotteryCreated(Lottery lottery) internal {
        address lotteryAddr = address(lottery);
        lotteries.push(lottery);

        emit LotteryCreate(lotteryAddr, msg.sender);
    }

    function setCreationCost(uint256 cost) external override {
        creationCost = cost;
    }

    function closeLottery() external {
        Lottery lottery = Lottery(msg.sender);
        (uint256 index, bool found) = getLotteryIndex(lottery);
        require(found, "Invalid lottery");

        databaseGame.addGame(msg.sender);

        casino.setGame(lottery, false);

        lotteries[index] = lotteries[lotteries.length - 1];
        lotteries.pop();
    }

    function getLotteryIndex(Lottery lottery)
        public
        view
        returns (uint256 index, bool found)
    {
        uint256 size = lotteries.length;

        for (uint256 i = 0; i < size; i++) {
            if (lotteries[i] == lottery) {
                return (i, true);
            }
        }

        return (0, true);
    }

    function setCasino(ICasino _casino) external override onlyOwner {
        casino = _casino;
    }

    function setGameDatabase(IDatabaseGame _dbGame)
        external
        override
        onlyOwner
    {
        databaseGame = _dbGame;
    }
}
