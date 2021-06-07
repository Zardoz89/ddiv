module ddiv.core.idmanager;

/// Id of a process
alias ProcessId = uint;

/** 
 * Manager of Ids
 * 
 * Generates a unique ID inside of the game engine.
 * Stores the next id and a stack of released ids.
 * When a new Id it's asked, try to use the last release id. If not, returns the next Id and increments nextId.
 */
private static struct IdManager {
    private ProcessId _nextId = 0;
    private ProcessId[] _freeIds;

    /// Resets the Id manager, setting the conter to 0, and cleaning the release ids stack.
    public void resetIds()
    {
        _nextId = 0;
        _freeIds.length = 0;
    }

    /// Generates the new Id
    public ProcessId getNewId()
    {
        if (_freeIds.length > 0) {
            ProcessId newId = _freeIds[$-1];
            _freeIds = _freeIds[0..$-1];
            return newId;
        }
        return _nextId++;
    }

    /// Release an used Id
    public void freeId(ProcessId id)
    {
        if (id < _nextId ) {
            if ((_nextId - 1) == id) {
                _nextId -= 1;
            } else {
                _freeIds ~= id;
            }
        }
    }
}

public __gshared IdManager idManager;

@("Id manager generation and release of Ids")
unittest
{
    import pijamas;
    idManager.resetIds();
    
    auto id = idManager.getNewId();
    id.should.be.equal(0);
    idManager._nextId.should.be.equal(1);

    idManager.resetIds();

    auto ids = [idManager.getNewId(), idManager.getNewId(), idManager.getNewId(), idManager.getNewId()];
    idManager._nextId.should.be.equal(4);
    ids.should.be.equal([0, 1, 2, 3]);

    idManager.freeId(3);
    idManager._freeIds.should.be.empty;
    idManager._nextId.should.be.equal(3);

    idManager.getNewId().should.be.equal(3);
    
    idManager.freeId(1);
    idManager._freeIds.should.include(1);
    idManager._nextId.should.be.equal(4);
    idManager.getNewId().should.be.equal(1);

}
