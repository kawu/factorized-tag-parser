{-# LANGUAGE CPP             #-}
{-# LANGUAGE TemplateHaskell #-}


module NLP.Partage.Earley.Item
(
-- * Span
  Span (..)
, beg
, end
, gap
, regular
, auxiliary

-- * Active
, Active (..)
, state
, spanA

-- * Passive
, Passive (..)
, dagID
, spanP

-- * Top
, Top (..)
, label
, spanT

-- * NonActive
, NonActive
, isTop
, spanN
, labelN

-- * Item
, Item (..)
, fromNonActive
-- , isRoot

-- #ifdef DebugOn
, printActive
, printPassive
, printTop
-- #endif
) where


import           Data.Lens.Light
import           Data.Maybe             (isJust, isNothing)
import           Prelude                hiding (span)

import           Data.DAWG.Ord          (ID)

import           NLP.Partage.Earley.Base (Pos)
import           NLP.Partage.DAG        (DID)
import qualified NLP.Partage.DAG as DAG

-- #ifdef DebugOn
import           NLP.Partage.Earley.Base (nonTerm)
import           NLP.Partage.Earley.Auto (Auto (..))
-- #endif


--------------------------------------------------
-- BASE TYPES
--------------------------------------------------


data Span = Span {
    -- | The starting position.
      _beg   :: Pos
    -- | The ending position (or rather the position of the dot).
    , _end   :: Pos
    -- | Coordinates of the gap (if applies)
    , _gap   :: Maybe (Pos, Pos)
    } deriving (Show, Eq, Ord)
$( makeLenses [''Span] )


-- | Does it represent regular rules?
regular :: Span -> Bool
regular = isNothing . getL gap


-- | Does it represent auxiliary rules?
auxiliary :: Span -> Bool
auxiliary = isJust . getL gap


-- | Active chart item : state reference + span.
data Active = Active {
      _state :: ID
    , _spanA :: Span
    } deriving (Show, Eq, Ord)
$( makeLenses [''Active] )


-- | Ordinary passive chart item : DAG node ID + span.
data Passive = Passive {
      _dagID :: DID
    , _spanP :: Span
    } deriving (Show, Eq, Ord)
$( makeLenses [''Passive] )


-- | Top-level passive chart item : label, value + span.
data Top n v = Top {
      _label :: n
    , _value :: v
    , _spanT :: Span
    } deriving (Show, Eq, Ord)
$( makeLenses [''Top] )


-- | One of the passive types.
type NonActive n v = Either Passive (Top n v)


-- | Does it represent a top-passive item?
isTop :: NonActive n v -> Bool
isTop x = case x of
  Left _ -> False
  _ -> True


-- | Span of a non-active item.
spanN :: NonActive n v -> Span
spanN item = case item of
  Left p -> getL spanP p
  Right p -> getL spanT p


-- | Label assigned to a given non-active item.
labelN :: NonActive n v -> Auto n t v -> n
labelN x auto = case x of
  Left p -> nonTerm (p ^. dagID) auto
  Right p -> p ^. label


-- | Create `Item` from `NonActive` item.
fromNonActive :: NonActive n v -> Item n v
fromNonActive x = case x of
  Left p -> ItemP p
  Right p -> ItemT p


-- | Passive or active item.
data Item n v
    = ItemT (Top n v)
    | ItemP Passive
    | ItemA Active
    deriving (Show, Eq, Ord)


-- UPDATE: the function below has no sense now that top passive items
-- are distinguished from ordinary ones.
-- -- | Does it represent a root?
-- isRoot :: Either n DID -> Bool
-- isRoot x = case x of
--     Left _  -> True
--     Right _ -> False


-- #ifdef DebugOn
-- | Print an active item.
printSpan :: Span -> IO ()
printSpan span = do
    putStr . show $ getL beg span
    putStr ", "
    case getL gap span of
        Nothing -> return ()
        Just (p, q) -> do
            putStr $ show p
            putStr ", "
            putStr $ show q
            putStr ", "
    putStr . show $ getL end span


-- | Print an active item.
printActive :: Active -> IO ()
printActive p = do
    putStr "("
    putStr . show $ getL state p
    putStr ", "
    printSpan $ getL spanA p
    putStrLn ")"


-- | Print a passive item.
printPassive :: (Show n) => Passive -> Auto n t a -> IO ()
printPassive p auto = do
    putStr "("
    let did = getL dagID p
    putStr $
      show (DAG.unDID did) ++ "[" ++
      show (nonTerm did auto) ++ "]"
    putStr ", "
    printSpan $ getL spanP p
    putStrLn ")"


-- | Print a top-passive item.
printTop :: (Show n, Show v) => Top n v -> IO ()
printTop p = do
    putStr "("
    putStr . show $ getL label p
    putStr ", "
    putStr . show $ getL value p
    putStr ", "
    printSpan $ getL spanT p
    putStrLn ")"
-- #endif
