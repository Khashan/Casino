pragma solidity ^0.8.4;

import "../libs/Database/IDatabaseGame.sol";
import "../libs/Game/IGame.sol";

contract DatabaseGame is IDatabaseGame {
    address[] public oldGames;
    mapping(address => bool) savedGames;
    ICasino casino;

    function addGame(address gameAddr) external override {
        IGame game = IGame(gameAddr);
        require(game.isDone(), "Game is not done");
        require(casino.isGame(game), "Not valid game");
        require(!savedGames[gameAddr], "Lottery already in the db");

        savedGames[gameAddr] = true;
        oldGames.push(gameAddr);
    }

    function getEndedGames() external view override returns (address[] memory) {
        return oldGames;
    }

    function setCasino(ICasino _casino) external override {
        casino = _casino;
    }
}
