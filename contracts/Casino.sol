pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./libs/ICasino.sol";

contract Casino is Ownable, ICasino {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public tokenCost = 1 ether;
    IERC20 public currencyToken;
    mapping(address => uint256) public userWallets;
    mapping(IGame => uint256) public gameWallets;
    mapping(IGame => bool) public games;

    address private casinoBank;
    address private treasury;
    IRandomizer private randomizer;

    event BuyToken(address indexed user, uint256 amount);
    event SellToken(address indexed user, uint256 amount);
    event TransferToken(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Migrate(ICasino indexed to);
    event Win(address indexed user, address indexed game, uint256 amount);

    constructor(IERC20 _currencyToken, IRandomizer _random) {
        currencyToken = _currencyToken;
        casinoBank = address(this);
        randomizer = _random;
    }

    modifier hasCurrency(uint256 _amount) {
        require(_amount > 0, "Invalid Amount");
        require(
            currencyToken.balanceOf(msg.sender) >= _amount,
            "Not enough fund"
        );
        _;
    }

    modifier hasTokens(uint256 _amount) {
        require(_amount > 0, "Invalid Amount");
        require(userWallets[msg.sender] >= _amount, "Not enough token");
        _;
    }

    modifier onlyGame {
        require(games[IGame(msg.sender)], "Not game");
        _;
    }

    function setGame(IGame _game, bool _status) external override onlyOwner {
        games[_game] = _status;
    }

    function buyToken(uint256 _amount) external override hasCurrency(_amount) {
        require(_amount > 0, "Not valid amount");

        currencyToken.safeTransferFrom(msg.sender, casinoBank, _amount);

        uint256 token = _amount.div(tokenCost);
        userWallets[msg.sender] += token;

        emit BuyToken(msg.sender, token);
    }

    function sellToken(uint256 _amount) external override {
        uint256 userTokens = userWallets[msg.sender];
        require(userTokens >= _amount, "Not enough token");

        uint256 currency = _amount.mul(tokenCost);
        require(
            currencyToken.balanceOf(casinoBank) >= _amount,
            "Not enough fund in the casino. try later"
        );

        userWallets[msg.sender] -= _amount;
        currencyToken.safeTransfer(msg.sender, currency);

        emit SellToken(msg.sender, _amount);
    }

    function getTokens(address _user) external view override returns (uint256) {
        return userWallets[_user];
    }

    function getGameTokens(IGame _game)
        external
        view
        override
        returns (uint256)
    {
        return gameWallets[_game];
    }

    function transferToken(address _user, uint256 _amount)
        external
        override
        hasTokens(_amount)
    {
        userWallets[msg.sender] -= _amount;
        userWallets[_user] += _amount;

        emit TransferToken(msg.sender, _user, _amount);
    }

    function takeToken(address _user, uint256 _amount) external override {
        IGame game = IGame(msg.sender);
        require(games[game], "Not a game");
        require(userWallets[_user] >= _amount, "Not enough tokens");

        userWallets[_user] -= _amount;
        gameWallets[game] += _amount;
    }

    function giveToken(address _user, uint256 _amount) external override {
        IGame game = IGame(msg.sender);
        require(games[game], "Not a game");
        require(gameWallets[game] >= _amount, "Not enough token.");

        gameWallets[game] -= _amount;
        userWallets[_user] += _amount;

        emit Win(_user, msg.sender, _amount);
    }

    function migrate(ICasino casino) external override {
        currencyToken.safeTransfer(
            address(casino),
            currencyToken.balanceOf(casinoBank)
        );

        emit Migrate(casino);
    }

    function getTreasury() external view override returns (address) {
        return treasury;
    }

    function setRandomizer(IRandomizer _randomizer)
        external
        override
        onlyOwner
    {
        randomizer = _randomizer;
    }

    function getRandomNumbers(
        uint256 _quantity,
        uint256 _mod,
        uint256 _offset
    ) external override onlyGame returns (uint256[] memory) {
        require(_quantity > 0, "Qty needs to be at least 1");

        bytes32 request =
            randomizer.getRandomNumber(
                uint256(
                    keccak256(abi.encode(block.timestamp, block.difficulty))
                )
            );

        return randomizer.fetchRandom(request, _quantity, _mod, _offset);
    }
}
