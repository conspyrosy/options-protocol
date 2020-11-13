const truffleAssert = require('truffle-assertions');

const USDC = artifacts.require('USDC')
const Option = artifacts.require('Option')

contract('Option', ([owner, minter, minter2, ...accounts]) => {
    let option;
    let expiredOption;
    let mintOptions;
    let usdc;

    before(async () => {
        usdc = await USDC.new();
        option = await Option.new(usdc.address, '100000000000000000000', '1618963199');
        expiredOption = await Option.new(usdc.address, '100000000000000000000', '0');

        mintOptions = async (optionCount, minterAddress) => {
            const optionCountWithDecimals = optionCount + '00000000000000000000';

            //transfer enough USDC balance to minter from usdc owner
            await usdc.transfer(minterAddress, optionCountWithDecimals, { from: owner });

            //approve spend of usdc by option contract
            await usdc.approve(option.address, optionCountWithDecimals, { from: minterAddress})

            //mint optionCount options
            await option.mintOption(optionCount, { from: minterAddress });
        }
    })

    it('should not allow a user to exercise options if the option has expired', async () => {
        truffleAssert.fails(
            expiredOption.exerciseOption(1),
            truffleAssert.ErrorType.REVERT,
            "This option has expired"
        );
    })

    it('should not allow a user to exercise options if they dont have enough option tokens', async () => {
        truffleAssert.fails(
            option.exerciseOption(1),
            truffleAssert.ErrorType.REVERT,
            "Not enough options to exercise that amount"
        );
    })

    it('should not allow a user to mint options if the option has expired', async () => {
        truffleAssert.fails(
            expiredOption.mintOption(1, { from: minter }),
            truffleAssert.ErrorType.REVERT,
            "This option has expired"
        );
    })

    it('should not allow a user to mint an option if they dont have enough strike collateral', async () => {
        truffleAssert.fails(
            option.mintOption(1, { from: minter }),
            truffleAssert.ErrorType.REVERT,
            "Not enough strike currency to mint that many tokens"
        );
    })

    it('should allow a user to mint an option if they have enough strike collateral', async () => {
        //mint 2 options
        await mintOptions('2', minter);

        const optionBalance = await option.balanceOf(minter);
        const usdcBalance = await usdc.balanceOf(minter);

        assert(optionBalance == '2', "Incorrect option balance after minting");
        assert(usdcBalance == '0', "Incorrect usdc balance after minting");
    })

    //TODO: Fix this test. currently broken...
    it('should allow a user to exercise options if they own enough tokens', async () => {
        //mint 2 options
        await mintOptions('2', minter2);

        const usdcBalanceBefore = await usdc.balanceOf(minter2);
        const optionBalanceBefore = await option.balanceOf(minter2);

        console.log("Balance before is " + usdcBalanceBefore);
        console.log("Option balance before is " + optionBalanceBefore);

        //approve options to be spent by options contract
        await option.approve(option.address, '2000000000000000000000', { from: minter2 })

        console.log("Allowable spend is " + await option.allowance(minter2, option.address));

        await option.exerciseOption(1, { from: minter2 });
        const usdcBalanceAfter = await usdc.balanceOf(minter2);
        const optionBalanceAfter = await option.balanceOf(minter2);

        //TODO check eth balance also
        console.log("Balance after is " + usdcBalanceAfter);
        console.log("Balance after is " + optionBalanceAfter);

        assert(usdcBalanceAfter == '100000000000000000000', "Incorrect balance after exercising")
    })

    it('should not allow a user to reclaim collateral if the option is active', async () => {

    })

    it('should allow a user to reclaim collateral once the option has expired', async () => {

    })

    it('should not allow a user to reclaim collateral once they have already done so', async () => {

    })

    it('should not allow a user to exercise options if they send incorrect amount of ETH', async () => {

    })
})