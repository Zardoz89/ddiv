module ddiv.core.idmanager;

/// Id of a process
public alias ProcessId = uint;

/// Id of the main process
public const ProcessId ROOT_ID = 1;
/// Father Id of a orphan process (Only the main process can be orphan)
public const ProcessId ORPHAN_FATHER_ID = 0;
public alias UNINITIALIZED_ID = ORPHAN_FATHER_ID;

private const FREE_IDS_ARRAY_BLQ_SIZE = 16 * 1024; // 16 KiB
private const ProcessId START_ID = 2;
import ddiv.core.mallocator;
import ddiv.container.stack;

/**
 * Manager of Ids
 *
 * Generates a unique ID inside of the game engine.
 * Stores the next id and a stack of released ids.
 * When a new Id it's asked, try to use the last release id. If not, returns the next Id and increments nextId.
 *
 * Special Ids :
 * 0 -- Not used. Not handled by the manager.
 * 1 -- Main process. Root of all process tree. Not handled by the manager
 */
public struct IdManager {
    private ProcessId _nextId = UNINITIALIZED_ID;
    private SimpleStack!ProcessId freeIds = void;
    private bool _initialized = false;

    void initialize() @nogc @trusted nothrow
    {
        if (! this._initialized) {
            this._nextId = START_ID;
            this.freeIds = SimpleStack!ProcessId(FREE_IDS_ARRAY_BLQ_SIZE);
            this._initialized = true;
        }
    }

    void deinitialize() @nogc @trusted nothrow
    {
        if (this._initialized) {
            this._nextId = UNINITIALIZED_ID;
            this.freeIds.clear();
            this._initialized = false;
        }
    }

    /// Resets the Id manager, setting the conter to 0, and cleaning the release ids stack.
    void resetIds() @nogc @trusted nothrow
    {
        this._nextId = START_ID;
        this.freeIds.clear();
    }

    /// Generates the new Id
    ProcessId getNewId() @nogc @trusted nothrow
    {
        if (this.freeIds.length > 0) {
            return this.freeIds.pop();
        }
        return this._nextId++;
    }

    bool existsId(ProcessId id) @nogc @trusted nothrow
    {
        if (id >= this._nextId) {
            return false;
        }
        return !this.freeIds.contains(id);
    }

    /// Release an used Id
    void freeId(ProcessId id) @nogc @trusted nothrow
    {
        if (this.existsId(id)) {
            this.freeIds.push(id);
        }
    }

    void optimize() @nogc @trusted nothrow
    {
        // TODO
        // Sort freeIds and try to shrink _nextId if there is a block of contigous free ids that it's contigous to _nextId ?
    }
}


@("Id manager generation and release of Ids")
unittest
{
    import pijamas;
    IdManager idManager;
    idManager.initialize();
    scope(exit) idManager.deinitialize();

    auto id = idManager.getNewId();
    id.should.be.equal(START_ID);
    idManager.existsId(id).should.be.True();
    idManager.existsId(100_000).should.be.False();
    idManager._nextId.should.be.equal(START_ID + 1);

    idManager.resetIds();

    auto ids = [idManager.getNewId(), idManager.getNewId(), idManager.getNewId(), idManager.getNewId()];
    idManager._nextId.should.be.equal(6);
    ids.should.be.equal([2, 3, 4, 5]);

    idManager.freeId(3);
    idManager.freeIds.length.should.be.equal(1);
    idManager._nextId.should.be.equal(6);

    idManager.getNewId().should.be.equal(3);

    idManager.freeId(5);
    idManager.freeIds.contains(5).should.be.True();
    idManager._nextId.should.be.equal(6);
    idManager.getNewId().should.be.equal(5);

    idManager.freeId(3);
    idManager.freeId(5);
    idManager.freeId(999);
    idManager.getNewId().should.be.equal(5);
    idManager.getNewId().should.be.equal(3);
    
    idManager.resetIds();

    // Stress test
    ProcessId[] usedIds;
    foreach(i ; 0 .. (FREE_IDS_ARRAY_BLQ_SIZE*2)) {
        usedIds ~= idManager.getNewId();
    }
    usedIds.should.have.length(FREE_IDS_ARRAY_BLQ_SIZE*2);
    foreach(idToFree ; usedIds) {
        idManager.freeId(idToFree);
    }
    idManager.freeIds.length.should.be.equal(usedIds.length);
    idManager.getNewId().should.be.equal(FREE_IDS_ARRAY_BLQ_SIZE*2 + 1 );
}
