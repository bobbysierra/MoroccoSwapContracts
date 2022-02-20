
const MoroccoSwapV2Pair = artifacts.require('MoroccoSwapV2Pair');
const MoroccoSwapV2Factory = artifacts.require('MoroccoSwapV2Factory');
const MoroccoSwapV2Router02 = artifacts.require('MoroccoSwapV2Router02');
const ERC20Mock = artifacts.require('ERC20Mock');
const WETH9Mock = artifacts.require('WETH9Mock');

const { time, constants } = require('@openzeppelin/test-helpers');
// const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const KYTHBank = artifacts.require('KYTHBank');
const ETHXBank = artifacts.require('ETHXBank');
const GoldXBank = artifacts.require('GoldXBank');
const BTCXBank = artifacts.require('BTCXBank');
const USDTXBank = artifacts.require('USDTXBank');

const MoroccoSwapFeeTransfer = artifacts.require('MoroccoSwapFeeTransfer');
const Roulette = artifacts.require('Roulette');

const MoroccoSwapFarm = artifacts.require('MoroccoSwapFarm');

const Evangelist = artifacts.require('Evangelist');


contract("swap", function (accounts) {


  before(async () => {
    //tokens
    this.kythToken = await ERC20Mock.new({ from: bob });
    this.usdtxToken = await ERC20Mock.new({ from: bob });
    this.goldxToken = await ERC20Mock.new({ from: bob });
    this.btcxToken = await ERC20Mock.new({ from: bob });
    this.ethxToken = await ERC20Mock.new({ from: bob });

    // bank contracts
    this.kythBank = await KYTHBank.new(this.kythToken.address)
    this.usdtxBank = await USDTXBank.new(this.usdtxToken.address)
    this.goldxBank = await GoldXBank.new(this.goldxToken.address)
    this.btcxBank = await BTCXBank.new(this.btcxToken.address)
    this.ethxBank = await ETHXBank.new(this.ethxToken.address)

    // roulette contract
    this.roulette = await Roulette.new(this.kythToken.address);

    // swap contracts
    this.weth = await WETH9Mock.new(18, { from: alice });
    this.factory = await MoroccoSwapV2Factory.new(alice, { from: alice });
    console.log("factory", (await this.factory.pairCodeHash()).toString());
    this.router = await MoroccoSwapV2Router02.new(this.factory.address, this.weth.address);

    await this.factory.setRouter(this.router.address);

    this.feeTransfer = await MoroccoSwapFeeTransfer.new(this.factory.address, this.router.address, alice);
    this.factory.setFeeTransfer(this.feeTransfer.address)
        // IMoroccoSwapV2Factory(_factory).setFeeTransfer(feeTransfer);

    this.evangelist =  await Evangelist.new()
    // farm
    this.farm = await MoroccoSwapFarm.new(this.factory.address, alice, this.evangelist.address, this.kythToken.address)

    // initial configuration
    // this.feeTransfer = await MoroccoSwapFeeTransfer.at((await this.factory.feeTransfer()).toString())   
    await this.feeTransfer.configure(
      global, 
      this.roulette.address,
      this.farm.address,
      this.kythBank.address,
      this.usdtxBank.address,
      this.goldxBank.address,
      this.btcxBank.address,
      this.ethxBank.address
    )

  });

  const alice = accounts[0];
  const bob = accounts[1];
  const minter = accounts[2];
  const elon = accounts[3];
  const stakeOwner = accounts[4];
  const admin = accounts[5];
  const global = accounts[6];
  const user1 = accounts[7];
  const user2 = accounts[8];
  const carol = accounts[9];


  it('add kythToken - usdtxToken liquidity successfully', async () => {

    await this.kythToken.mint(carol, web3.utils.toWei('2000'), { from: carol })
    await this.kythToken.approve(this.router.address, web3.utils.toWei('1000'), { from: carol })

    await this.usdtxToken.mint(carol, web3.utils.toWei('2000'), { from: carol })
    await this.usdtxToken.approve(this.router.address, web3.utils.toWei('1000'), { from: carol })

    // await this.factory.pauseFee(true);
    await this.router.addLiquidity(this.kythToken.address, this.usdtxToken.address, web3.utils.toWei('1000'), web3.utils.toWei('100'),
      0, 0, carol, Number(await time.latest()) + 123, { from: carol })
    
      
    // console.log("usdtxToken alice",(await this.usdtxToken.balanceOf(alice)).toString())
    // console.log("usdtxToken roulette ",(await this.usdtxToken.balanceOf(this.roulette.address)).toString())
    // console.log("usdtxToken global ",(await this.usdtxToken.balanceOf(global)).toString())

    // console.log("kythToken alice",(await this.kythToken.balanceOf(alice)).toString())
    // console.log("kythToken roulette ",(await this.kythToken.balanceOf(this.roulette.address)).toString())
    // console.log("kythToken global ",(await this.kythToken.balanceOf(global)).toString())

    this.lp = await MoroccoSwapV2Pair.at((await this.factory.getPair(this.kythToken.address, this.usdtxToken.address)).toString())
    console.log("lp pair ",(await this.lp.balanceOf(carol)).toString())
  })

  it('add goldxToken - weth liquidity successfully', async () => {

    await this.goldxToken.mint(elon, web3.utils.toWei('2000'), { from: elon })
    await this.goldxToken.approve(this.router.address, web3.utils.toWei('1000'), { from: elon })

    await this.router.addLiquidityETH(this.goldxToken.address, web3.utils.toWei('200'), 0, 0, elon, Number(await time.latest()) + 123, { from: elon, value: web3.utils.toWei('200') })

  })

  it('eth - kyth successfully', async () => {

    await this.kythToken.mint(bob, web3.utils.toWei('400'), { from: bob })
    await this.kythToken.approve(this.router.address, web3.utils.toWei('200'), { from: bob })
    await this.router.addLiquidityETH(this.kythToken.address, web3.utils.toWei('200'), 0, 0, bob, Number(await time.latest()) + 123, { from: bob, value: web3.utils.toWei('200') })
  // console.log("swapKythConverter",(await this.goldxToken.balanceOf(this.swapKythConverter.address)).toString())
    // [this.weth.address, this.kythToken.address],
    // eth - kyth
    var erkmoonPair = (await this.factory.getPair(this.weth.address, this.kythToken.address)).toString()
    const cakesushiLp  = await MoroccoSwapV2Pair.at(erkmoonPair);
    await cakesushiLp.approve(this.router.address, web3.utils.toWei('1000000'), {from: bob } )
    console.log("cakesushiLp",(await cakesushiLp.balanceOf(bob)).toString())
    // await this.factory.pauseFee(true);

      await this.router.removeLiquidity(
        this.weth.address, 
        this.kythToken.address,
        web3.utils.toWei('4'),
        0,
        0,
        bob,
        (Number(await time.latest())+123), {from: bob }) 


  })

  it('do some swap', async () => {

    await this.weth.deposit({ from: user2, value: web3.utils.toWei('400') })
    await this.weth.approve(this.router.address, web3.utils.toWei('200'), { from: user2 })

    // console.log("weth alice",(await this.weth.balanceOf(alice)).toString())
    // console.log("weth roulette ",(await this.weth.balanceOf(this.roulette.address)).toString())
    // console.log("weth global ",(await this.weth.balanceOf(global)).toString())


    await this.router.swapExactTokensForTokens(
      web3.utils.toWei('1'),
      0,
      [this.weth.address, this.kythToken.address],
      user2,
      Number(await time.latest()) + 123,
      { from: user2 })

    // console.log("weth alice",(await this.weth.balanceOf(alice)).toString())
    // console.log("weth roulette ",(await this.weth.balanceOf(this.roulette.address)).toString())
    // console.log("weth global ",(await this.weth.balanceOf(global)).toString())

    await this.goldxToken.mint(user2, web3.utils.toWei('1'), { from: user2 })
    await this.goldxToken.approve(this.router.address, web3.utils.toWei('1'), { from: user2 })

    // console.log("swapKythConverter",(await this.goldxToken.balanceOf(this.swapKythConverter.address)).toString())

    await this.router.swapExactTokensForETH(
      web3.utils.toWei('1'),
      0,
      [this.goldxToken.address, this.weth.address],
      user2,
      Number(await time.latest()) + 123,
      { from: user2 })

  

  })

  // farming 
  it('farming successfully', async () => {

    // function setEvangalist(address referral) external {
    await this.evangelist.setEvangalist(accounts[0],{from:accounts[11]})
    await this.evangelist.setEvangalist(accounts[11],{from:accounts[12]})
    await this.evangelist.setEvangalist(accounts[12],{from:accounts[13]})
    await this.evangelist.setEvangalist(accounts[13],{from:accounts[14]})
    await this.evangelist.setEvangalist(accounts[14],{from:accounts[15]})
    await this.evangelist.setEvangalist(accounts[15],{from:accounts[16]})
    await this.evangelist.setEvangalist(accounts[16],{from:accounts[17]})
    await this.evangelist.setEvangalist(accounts[17],{from:accounts[18]})
    await this.evangelist.setEvangalist(accounts[18],{from:accounts[19]})
    await this.evangelist.setEvangalist(accounts[19],{from:accounts[20]})
    await this.evangelist.setEvangalist(accounts[20],{from:accounts[21]})
    await this.evangelist.setEvangalist(accounts[21],{from:carol})

   
  this.lp = await MoroccoSwapV2Pair.at((await this.factory.getPair(this.kythToken.address, this.usdtxToken.address)).toString())
  console.log("lp pair ",(await this.lp.balanceOf(carol)).toString())
  // addWhiteListLPInfo(IERC20[] calldata _lpToken) 
  await this.farm.addWhiteListLPInfo([this.lp.address])
  await this.lp.approve(this.farm.address, 5000, {from: carol});
  await this.farm.deposit(0, 5000, {from:carol});

  // do some swaps
  await this.kythToken.mint(user2, web3.utils.toWei('1111'), { from: user2 })
  await this.kythToken.approve(this.router.address, web3.utils.toWei('200'), { from: user2 })

  await this.usdtxToken.mint(user2, web3.utils.toWei('1'), { from: user2 })
  await this.usdtxToken.approve(this.router.address, web3.utils.toWei('200'), { from: user2 })


  await this.router.swapExactTokensForTokens(
    web3.utils.toWei('1'),
    0,
    [this.kythToken.address, this.usdtxToken.address],
    user2,
    Number(await time.latest()) + 123,
    { from: user2 })

    await this.router.swapExactTokensForTokens(
      web3.utils.toWei('1'),
      0,
      [this.usdtxToken.address, this.kythToken.address],
      user2,
      Number(await time.latest()) + 123,
      { from: user2 })

     await this.kythToken.mint(alice, web3.utils.toWei('1'))
     await this.kythToken.approve(this.farm.address, web3.utils.toWei('200'))

     await this.farm.addFarmReward("5000");

    console.log(" kyth ",(await this.kythToken.balanceOf(carol)).toString())
    console.log(" usdtx ",(await this.usdtxToken.balanceOf(carol)).toString())

     await this.farm.claimReward(0,{from:carol})
     await this.farm.claimFarmKyth(0,{from:carol})

     await this.farm.addEvangeListReward("1000")
     await this.farm.addEvangeListReward("1000")

     console.log(" kyth ",(await this.kythToken.balanceOf(carol)).toString())
     console.log(" usdtx ",(await this.usdtxToken.balanceOf(carol)).toString())

    //  evangelistInfo[_userAddr][round]
    var evn = await this.farm.evangelistInfo(accounts[21],1)
    console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[20],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[19],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[18],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[17],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[16],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[15],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[14],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[13],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[12],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[11],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    // evn = await this.farm.evangelistInfo(accounts[10],1)
    // console.log("evn", evn[0].toString(),  evn[1].toString(), evn[2].toString())

    console.log("***")
    // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[21])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[20])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[19])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[18])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[17])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[16])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[15])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[14])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[13])).toString())
    // // console.log(" kyth ",(await this.kythToken.balanceOf(accounts[12])).toString())

    var creditPointsInfo = (await this.farm.creditPointsInfo(1))
    console.log("creditPointsInfo kyth",creditPointsInfo[0].toString(), creditPointsInfo[1].toString() )

    console.log("getEvangeListReawrd  ",(await this.farm.getEvangeListReward(1, accounts[21])).toString())
    // await this.farm.claimEvangelistKyth(1,{from:accounts[21]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[13]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[14]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[15]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[16]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[17]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[18]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[19]}) 
   await this.farm.claimEvangelistKyth(1,{from:accounts[20]})
   await this.farm.claimEvangelistKyth(1,{from:accounts[21]}) 
  //  await this.farm.claimEvangelistKyth(1,{from:accounts[22]}) 

console.log("***")
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[21])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[20])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[19])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[18])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[17])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[16])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[15])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[14])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[13])).toString())
  //  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[12])).toString())
   
})

it('roulette successfully', async () => {

  // addRound(uint256 amount) external onlyOperatorOrOwner
  await this.roulette.addRound(1000)
  await this.kythToken.mint(this.roulette.address, 1000)

  await this.roulette.spin({from:accounts[26]}) 
  await this.roulette.spin({from:accounts[27]}) 
  await this.roulette.spin({from:accounts[28]})
  await this.roulette.spin({from:accounts[29]}) 
  await this.roulette.spin({from:accounts[30]}) 

  await this.roulette.spin({from:accounts[26]}) 
  await this.roulette.spin({from:accounts[27]}) 
  await this.roulette.spin({from:accounts[28]})
  await this.roulette.spin({from:accounts[29]}) 
  await this.roulette.spin({from:accounts[30]}) 

  console.log("***")
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[26])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[27])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[28])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[29])).toString())
   console.log(" kyth ",(await this.kythToken.balanceOf(accounts[30])).toString())

  await time.increase(2 * 86400)

  
  await this.roulette.claim({from:accounts[26]})   
  await this.roulette.claim({from:accounts[27]})    
  await this.roulette.claim({from:accounts[28]})  
  await this.roulette.claim({from:accounts[29]})   
  await this.roulette.claim({from:accounts[30]})    

  console.log("***")
  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[26])).toString())
  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[27])).toString())
  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[28])).toString())
  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[29])).toString())
  console.log(" kyth ",(await this.kythToken.balanceOf(accounts[30])).toString())

  // await this.roulette.spin({from:accounts[27]}) 

})




})

// ganache-cli -a 1000 --gasLimit '99721975' --gasPrice '0' --allowUnlimitedContractSize -e=1000

// truffle test ./test/swap.test.js --compile-none network development --show-events
