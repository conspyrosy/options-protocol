pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Option is ERC20 {
    using SafeMath for uint256;

    address public strikeCurrency;
    uint256 public strikePrice;
    uint256 public expiryDate;
    address[] public activeMinterList;
    mapping(address => uint256) public activeMinterOptions;

    struct ReclaimableCurrency {
        uint256 reclaimableETH;
        uint256 reclaimableStrike;
    }

    constructor(address _strikeCurrency, uint256 _strikePrice, uint256 _expiryDate) ERC20("Option", "Option") public {
        strikeCurrency = _strikeCurrency;
        strikePrice = _strikePrice;
        expiryDate = _expiryDate;
    }

    /**
     * Takes required collateral to be fully collaterized and in return gives back an option token
     */
    function mintOption(uint256 optionsToCreate) external {
        IERC20 strike = IERC20(strikeCurrency);

        uint256 collateralRequired = optionsToCreate.mul(strikePrice);

        require(block.timestamp < expiryDate, "This option has expired");
        require(strike.balanceOf(msg.sender) >= collateralRequired, "Not enough strike currency to mint that many tokens");

        strike.transferFrom(msg.sender, address(this), collateralRequired);

        uint256 previouslyMintedOptions = activeMinterOptions[msg.sender];

        //if the user has not previously minted options, register them in the list.
        if(previouslyMintedOptions == 0) {
            activeMinterList.push(msg.sender);
        }

        //update the map with the new total tokens minted by this user
        activeMinterOptions[msg.sender] = previouslyMintedOptions.add(optionsToCreate);

        _mint(msg.sender, optionsToCreate); //TODO: ** decimals

        emit OptionsMinted(address(this), optionsToCreate);
    }

    /**
     * Given an amount of options, will exercise them if enough tokens are owned and option hasn't expired.
     */
    function exerciseOption(uint256 tokensToExercise) external payable {
        require(block.timestamp < expiryDate, "This option has expired");
        require(balanceOf(msg.sender) >= tokensToExercise, "Not enough options to exercise that amount");
        //TODO: check eth sent is correct value...
        //require(msg.value == tokensToExercise, "Not enough ETH provided");

        transferFrom(msg.sender, address(this), tokensToExercise);

        _burn(address(this), tokensToExercise);

        uint256 exchangeAmount = strikePrice.mul(msg.value);

        //give back strike * optionsAmount
        IERC20(strikeCurrency).transfer(msg.sender, exchangeAmount);

        emit OptionsExercised(msg.sender, exchangeAmount);
    }

    /**
     * Calculates total active options (from all addresses). By active we mean collateral has not been reclaimed by minters.
     * This method loops through active minter list and tallys their option counts.
     */
    function totalActiveOptions() public returns(uint256 totalActiveOptions) {
        uint256 totalActiveOptions = 0;
        for (uint i = 0; i < activeMinterList.length; i++) {
            totalActiveOptions = totalActiveOptions.add(activeMinterOptions[activeMinterList[i]]);
        }
        return totalActiveOptions;
    }

    /**
     * Calculates the amount of options minted by an address. This becomes 0 once collateral is reclaimed by an address.
     */
    function getUsersActiveOptions(address userAddress) public returns(uint256 totalMintedOptions) {
        return activeMinterOptions[userAddress];
    }

    /**
     * Calculates amount of collateral available to be claimed.
     */
    function reclaimableCollateral(address userAddress) public returns(ReclaimableCurrency memory reclaimableValues) {
        require(block.timestamp > expiryDate, "Can't calculate claimable collateral effectively while options are active");

        uint256 totalActiveOptions = totalActiveOptions();
        uint256 usersOptions = 0;

        uint256 reclaimableEthCollateral = 0;
        uint256 reclaimableStrikeCollateral = 0;

        if(usersOptions > 0) {
            uint256 totalETHCollateral = address(this).balance;
            uint256 totalStrikeCollateral = IERC20(strikeCurrency).balanceOf(address(this));

            uint256 usersPoolShare = usersOptions.div(totalActiveOptions);

            reclaimableEthCollateral = totalETHCollateral.mul(usersPoolShare);
            reclaimableStrikeCollateral = totalStrikeCollateral.mul(usersPoolShare);
        }

        return ReclaimableCurrency(reclaimableEthCollateral, reclaimableStrikeCollateral);
    }

    /**
     * Calling this function after the option has expired will allow the minter to reclaim their share of the collateral pool.
     */
    function reclaimCollateral() external {
        require(block.timestamp > expiryDate, "You can't reclaim collateral until the option expires!");
        ReclaimableCurrency memory reclaimableCurrencyForUser = reclaimableCollateral(msg.sender);
        require((reclaimableCurrencyForUser.reclaimableETH > 0 || reclaimableCurrencyForUser.reclaimableStrike > 0), "No collateral to claim");

        //TODO: unfinished, this is needed... remove user from active minter list, and reshuffle list to fill hole (last position becomes deleted position).
        //TODO: without this they can keep reclaiming...
        //delete activeMinterList[0];
        //activeMinterOptions[msg.sender] = 0;

        msg.sender.transfer(reclaimableCurrencyForUser.reclaimableETH);
        IERC20(strikeCurrency).transfer(msg.sender, reclaimableCurrencyForUser.reclaimableStrike);

        emit CollateralReclaimed(msg.sender, reclaimableCurrencyForUser.reclaimableETH, reclaimableCurrencyForUser.reclaimableStrike);
    }

    /**
     * Emitted when some options are exercised
     */
    event OptionsExercised(address exerciser, uint256 amountExercised);

    /**
     * Emitted when some options are minted
     */
    event OptionsMinted(address minter, uint256 amountMinted);

    /**
     * Emitted when a minter reclaims their collateral
     */
    event CollateralReclaimed(address minter, uint256 reclaimedETH, uint256 reclaimedStrikeCurrency);
}
