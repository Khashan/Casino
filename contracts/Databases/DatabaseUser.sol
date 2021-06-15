pragma solidity ^0.8.4;

import "../libs/ICasino.sol";
import "../libs/Database/IDatabaseUser.sol";

contract DatabaseUser is IDatabaseUser, Ownable {
    mapping(address => User) userDatas;
    ICasino public casino;

    function setCasino(ICasino _casino) external override onlyOwner {
        casino = _casino;
    }

    modifier isGame {
        require(casino.isGame(IGame(msg.sender)), "Only games can call this");
        _;
    }

    function userWon(address user) external override isGame {
        userDatas[user].gamesWon.push(msg.sender);
    }

    function userCreated(address user) external override isGame {
        userDatas[user].gamesCreated.push(msg.sender);
    }

    function userJoined(address user) external override isGame {
        userDatas[user].gamesParticipated.push(msg.sender);
    }

    function getUser(address user)
        external
        view
        override
        returns (User memory)
    {
        return userDatas[user];
    }
}
