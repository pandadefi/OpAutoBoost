# @version 0.3.7

from vyper.interfaces import ERC20

interface Boost:
    def stakingToken() -> address: view
    def stake(amount: uint256) -> uint256: nonpayable
    def withdraw(amount: uint256) -> uint256: nonpayable
    def balanceOf(account: address) -> uint256: view
    def earned(account: address) -> uint256: view
    def getReward() -> uint256: nonpayable
    def exit() -> uint256: nonpayable

interface Vault:
    def token() -> address: view
    def balanceOf(account: address) -> uint256: view
    def deposit(amount: uint256) -> uint256: nonpayable
    def withdraw(amount: uint256) -> uint256: nonpayable
    def transferFrom(sender: address, recipient: address, amount: uint256) -> bool: nonpayable
    def transfer(recipient: address, amount: uint256) -> bool: nonpayable
    def approve(spender: address, amount: uint256) -> bool: nonpayable

struct SwapParams:
    path: Bytes[10000]
    recipient: address
    amountIn: uint256
    minAmountOut: uint256

interface ISwapRouter:
    def swap(params: SwapParams) -> uint256: payable
   
# @dev Returns the address of the current owner.
owner: public(address)
bot: public(address)

# @dev Returns the address of the pending owner.
pending_owner: public(address)
# Uniswap v3 path
path: public(Bytes[10000])

# immutable
BOOST: public(immutable(Boost))
VAULT: public(immutable(Vault))
TOKEN: public(immutable(ERC20))
# constant
UNIV3_ROUTER: constant(address) = 0xE592427A0AEce92De3Edee1F18E0157C05861564
OP: constant(address) = 0x4200000000000000000000000000000000000042
OP_VAULT: constant(address) = 0x7D2382b1f8Af621229d33464340541Db362B4907

# @dev Emitted when the ownership transfer from
# `previous_owner` to `new_owner` is initiated.
event OwnershipTransferStarted:
    previous_owner: indexed(address)
    new_owner: indexed(address)


# @dev Emitted when the ownership is transferred
# from `previous_owner` to `new_owner`.
event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)

@external
def __init__(
    boost: address,
    owner: address,
    bot: address,
    path: Bytes[10000]
):
    self._transfer_ownership(owner)
    BOOST = Boost(boost)
    VAULT = Vault(BOOST.stakingToken())
    TOKEN = ERC20(VAULT.token())
    self.path = path

@external
def stake(_amount: uint256):
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = VAULT.balanceOf(msg.sender)
    VAULT.transferFrom(msg.sender, self, amount)

    self._stake(amount)

@external
def deposit(_amount: uint256):
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = TOKEN.balanceOf(msg.sender)
    TOKEN.transferFrom(msg.sender, self, amount)
    TOKEN.approve(VAULT.address, amount)
    amount = VAULT.deposit(amount)
    self._stake(amount)

@internal
def _stake(amount: uint256):
    VAULT.approve(BOOST.address, amount)
    BOOST.stake(amount)

@external
def withdraw(_amount: uint256):
    """
    @dev Withdraws `amount` of the staked tokens
         from the boost and vault and transfers them to the
         owner.
    """
    self._check_owner()
    self._unstake(_amount)
    amount: uint256 = VAULT.withdraw(_amount)
    TOKEN.transfer(self.owner, amount)

@external
def unstake(amount: uint256):
    """
    @dev Unstakes `amount` of the staked tokens
         from the boost and transfers vault tokens to the
         owner.
    """
    self._check_owner()
    self._unstake(amount)
    VAULT.transfer(self.owner, amount)

@internal
def _unstake(_amount: uint256):
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = BOOST.balanceOf(self.owner)
    BOOST.withdraw(amount)

@internal
def auto_compond(_path: Bytes[10000]) -> uint256:
    self._check_bot()
    path: Bytes[10000] = _path

    if path == empty(Bytes[10000]):
        path = self.path

    BOOST.getReward()
    amount: uint256 = Vault(OP_VAULT).withdraw(max_value(uint256))
    ERC20(OP).approve(UNIV3_ROUTER, amount)
    ISwapRouter(UNIV3_ROUTER).swap(SwapParams({
        path: path,
        recipient: self,
        amountIn: amount,
        minAmountOut: 0
    }))
    amount = TOKEN.balanceOf(self)
    TOKEN.approve(VAULT.address, amount)
    amount = VAULT.deposit(amount)
    BOOST.stake(amount)
    return amount


@external
def update_bot(bot: address):
    self._check_owner()
    self.bot = bot

@external
def rescue(contract: address, payload: Bytes[10000]):
    self._check_owner()
    raw_call(contract, payload)

# Ownable2Step

@external
def transfer_ownership(new_owner: address):
    """
    @dev Starts the ownership transfer of the contract
         to a new account `new_owner`.
    @notice Note that this function can only be
            called by the current `owner`. Also, there is
            no security risk in setting `new_owner` to the
            zero address as the default value of `pending_owner`
            is in fact already the zero address and the zero
            address cannot call `accept_ownership`. Eventually,
            the function replaces the pending transfer if
            there is one.
    @param new_owner The 20-byte address of the new owner.
    """
    self._check_owner()
    self.pending_owner = new_owner
    log OwnershipTransferStarted(self.owner, new_owner)


@external
def accept_ownership():
    """
    @dev The new owner accepts the ownership transfer.
    @notice Note that this function can only be
            called by the current `pending_owner`.
    """
    assert self.pending_owner == msg.sender, "Ownable2Step: caller is not the new owner"
    self._transfer_ownership(msg.sender)


@external
def renounce_ownership():
    """
    @dev Sourced from {Ownable-renounce_ownership}.
    @notice See {Ownable-renounce_ownership} for
            the function docstring.
    """
    self._check_owner()
    self._transfer_ownership(empty(address))


@internal
def _check_owner():
    """
    @dev Throws if the sender is not the owner.
    """
    assert msg.sender == self.owner, "Ownable2Step: caller is not the owner"

@internal
def _check_bot():
    """
    @dev Throws if the sender is not the bot.
    """
    assert msg.sender == self.bot, "Ownable2Step: caller is not the bot"

@internal
def _transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner` and deletes
         any pending owner.
    @notice This is an `internal` function without
            access restriction.
    @param new_owner The 20-byte address of the new owner.
    """
    self.pending_owner = empty(address)
    old_owner: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old_owner, new_owner)