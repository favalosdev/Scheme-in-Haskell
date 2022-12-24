module Main where

-- Commit test

import Text.ParserCombinators.Parsec hiding (spaces)
import System.Environment
import Control.Monad
import Numeric

data LispVal = Atom String
            |  List [LispVal]
            |  DottedList [LispVal] LispVal
            |  Number Integer
            |  String String
            |  Bool Bool
            |  Character Char
            |  Float Rational

instance Show LispVal where show = showVal

-- Parsing section

symbol :: Parser Char
symbol = oneOf "!#$%&|*+-/:<=>?@^_~"

spaces :: Parser ()
spaces = skipMany1 space

{-
Excercise 2.3.5 (DONE)
Add a Character constructor to LispVal, and create
a parser for character literals as described in R5RS.
-}
parseLiteral :: Parser LispVal
parseLiteral =
    do
        string "#\\"
        literal <- (string "space" >> return ' ')
               <|> (string "newline" >> return '\n')
               <|> letter
               <|> digit
               <|> symbol
        return $ Character literal

{-
Excercise 2.3.2 (DONE)
Our strings aren't quite R5RS compliant, because they don't support
escaping of internal quotes within the string. Change parseString
so that \" gives a literal quote character instead of terminating
the string. You may want to replace noneOf "\"" with a new parser 
action that accepts either a non-quote character or a backslash
followed by a quote mark.
-}

-- How the fuck do we make this work on Windows
parseString :: Parser LispVal
parseString =
    do
        char '"'
        x <- many (parseEscape <|> noneOf "\"")
        char '"'
        return $ String x

{-
Excercise 2.3.3 (DONE)
Modify the previous exercise to support \n, \r, \t, \\, and any other desired escape characters
-}
parseEscape :: Parser Char
parseEscape =
    do
        char '\\'
        escape <- oneOf "nrt\"\\"
        return (case escape of
                    'n' -> '\n'
                    'r' -> '\r'
                    't' -> '\t'
                    '"' -> escape
                    '\\' -> escape)

parseAtom :: Parser LispVal
parseAtom = 
    do
        first <- letter <|> symbol
        rest <- many (letter <|> digit <|> symbol)
        let atom = first:rest
        return $ case atom of
                        "#t" -> Bool True
                        "#f" -> Bool False
                        _    -> Atom atom

{-
Excercise 2.3.1 (DONE):
Rewrite parseNumber, without liftM, using
    1. do-notation
    2. explicit sequencing with the >>= operator

Excercise 2.3.4 (DONE):
Change parseNumber to support the Scheme standard for different
bases. You may find the readOct and readHex functions useful.
-}

parseNumber :: Parser LispVal
parseNumber = parseQuantity 'd'
          <|> do
                char '#'
                oneOf "bodx" >>= parseQuantity

parseQuantity :: Char -> Parser LispVal
parseQuantity base =
    do
        digits <- many1 digit
        let transformer = case base of
                                'b' -> readBin
                                'o' -> readOct
                                'd' -> readDec
                                'x' -> readHex
        return $ (Number . fst . head . transformer) digits

{-
Excercise 2.4.1:
Add support for the backquotesyntactic sugar: the
Scheme standard details what it should expand into
(quasiquote/unquote).
-}

parseQuoted :: Parser LispVal
parseQuoted =
    do
        char '\''
        x <- parseExpr
        return $ List [Atom "quote", x]


{-
Excercise 2.4.3: (PENDING)
Instead of using the try combinator, left-factor the grammar
so that the common subsequence is its own parser. You should
end up with a parser that matches a string of expressions, and
one that matches either nothing or a dot and a single expression.
Combining the return values of these into either a List or a
DottedList is left as a (somewhat tricky) exercise for the
reader: you may want to break it out into another helper function.
-}

-- Make this function as general as possible

parseList :: Parser LispVal
parseList = liftM List $ sepBy parseExpr spaces

parseDottedList :: Parser LispVal
parseDottedList =
    do
        head <- endBy parseExpr spaces
        tail <- char '.' >> spaces >> parseExpr
        return $ DottedList head tail

parseExpr :: Parser LispVal
parseExpr = parseLiteral
        <|> parseString
        <|> parseAtom
        <|> parseNumber
        <|> parseQuoted
        <|> do 
                char '('
                x <- try parseList <|> parseDottedList
                char ')'
                return x

-- Evaluation: part 1

showVal :: LispVal -> String
showVal (String contents) = "\"" ++ contents ++ "\""
showVal (Atom name) = name
showVal (Number contents) = show contents
showVal (Bool True) = "#t"
showVal (Bool False) = "#f"
showVal (Character literal) = [literal]

showVal (List contents) = "(" ++ unwordsList contents ++ ")"
showVal (DottedList head tail) = "(" ++ unwordsList head ++ " . " ++ showVal tail ++ ")"

unwordsList :: [LispVal] -> String
unwordsList = unwords . map showVal

eval :: LispVal -> LispVal
eval val@(String _) = val
eval val@(Atom _) = val
eval val@(Number _) = val
eval val@(Bool _) = val
eval val@(Character _) = val
eval (List [Atom "quote", val]) = val
eval (List (Atom func : args)) = apply func $ map eval args

apply :: String -> [LispVal] -> LispVal
apply func args = maybe (Bool False) ($ args) $ lookup func primitives

-- Primitives

primitives :: [(String, [LispVal] -> LispVal)]
primitives = [("+", numericBinop (+)),
              ("-", numericBinop (-)),
              ("*", numericBinop (*)),
              ("/", numericBinop div),
              ("mod", numericBinop mod),
              ("quotient", numericBinop quot),
              ("remainder", numericBinop rem),
              ("symbol?", isSymbol),
              ("string?", isString),
              ("number?", isNumber)]

numericBinop :: (Integer -> Integer -> Integer) -> [LispVal] -> LispVal
numericBinop op params = Number $ foldl1 op $ map unpackNum params

isSymbol :: LispVal -> LispVal
isSymbol (Bool _) = Bool True
isSymbol _ = Bool False

isString :: LispVal -> LispVal
isString (String _) = Bool True
isString _ = Bool False

isNumber :: LispVal -> LispVal
isNumber (Number _) = Bool True
isNumber _ = Bool False

{--
Excercise 3.1.2 (DONE)
Change unpackNum so that it always returns 0 if the value
is not a number, even if it's a string or list that could
be parsed as a number.
-}
unpackNum :: LispVal -> Integer
unpackNum (Number n) = n
unpackNum _ = 0

-- Output

readExpr :: String -> LispVal
readExpr input = case parse parseExpr "lisp" input of
    Left err -> String $ "No match: " ++ show err
    Right val -> val

main :: IO ()
main = getArgs >>= print . eval . readExpr . head
