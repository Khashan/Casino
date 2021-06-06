pragma solidity ^0.8.4;

import "./Game/IGame.sol";
import "./IRandomizer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICasino {
    function setGame(IGame _game, bool _status) external;

    function buyToken(uint256 _amount) external;

    function sellToken(uint256 _amount) external;

    function getTokens(address user) external view returns (uint256);

    function getGameTokens(IGame game) external view returns (uint256);

    function transferToken(address _user, uint256 _amount) external;

    function takeToken(address _user, uint256 _amount) external;

    function giveToken(address _user, uint256 _amount) external;

    function migrate(ICasino casino) external;

    function setRandomizer(IRandomizer _randomizer) external;

    function getRandomNumbers(
        uint256 _quantity,
        uint256 _mod,
        uint256 _offset
    ) external returns (uint256[] memory expandedValues);
}
