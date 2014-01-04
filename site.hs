--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import Control.Applicative ((<$>))
import Data.Monoid (mappend)
import Hakyll
import Site.Fields
import Site.Pandoc

--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith config $ do

    match ("images/*" .||. "favicon.ico" .||. "js/*" .||. "resources/*") $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    categories <- buildCategories "projects/*/*" $ fromCapture "projects/*.markdown"

    tagsRules categories $ \tag pattern -> do
        route $ setExtension "html"
        compile $ do
            posts <- postList categories pattern "templates/category-posts.html" recentFirst
            compiled <- getResourceBody >>= pandocHtml5Compiler (storeDirectory config)
            loadAndApplyTemplate "templates/project.html" (constField "posts" posts `mappend` defaultContext) compiled
            >>= loadAndApplyTemplate "templates/default.html" (mathCtx `mappend` defaultContext)
            >>= relativizeUrls

    match "projects/*/*" $ do
        route $ setExtension "html"
        compile $ do
            compiled <- getResourceBody >>= pandocHtml5Compiler (storeDirectory config)
            loadAndApplyTemplate "templates/post.html" (categoryField "category" categories `mappend` postCtx) compiled
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" (mathCtx `mappend` postCtx)
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- postList categories "projects/*/*" "templates/archive-posts.html" recentFirst
            let archiveCtx =
                    constField "posts" posts      `mappend`
                    constField "title" "Archives" `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["projects.html"] $ do
        route idRoute
        compile $ do
            projects <- recentFirst =<< loadAll "projects/*"
            let projectCtx =
                    listField "projects" defaultContext (return projects) `mappend`
                    constField "title" "Projects"                         `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/projects.html" projectCtx
                >>= loadAndApplyTemplate "templates/default.html"  projectCtx
                >>= relativizeUrls

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- (take 10) <$> (recentFirst =<< loadAllSnapshots "projects/*/*" "content")
            renderAtom atomFeedConfig feedCtx posts


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- (take 5) <$> (recentFirst =<< loadAll "projects/*/*")
            projects <- (take 5) <$> (recentFirst =<< loadAll "projects/*")
            let indexCtx =
                    listField "posts" postCtx (return posts)              `mappend`
                    listField "projects" defaultContext (return projects) `mappend`
                    constField "title" "Home"                             `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
config :: Configuration
config = defaultConfiguration
         { deployCommand = "rsync -avz -e ssh ./_site/ Neophilus:www/cqplabs" }

atomFeedConfig :: FeedConfiguration
atomFeedConfig = FeedConfiguration
    { feedTitle       = "CQPLabs"
    , feedDescription = "The hare-brained scheme division of CQP"
    , feedAuthorName  = "CQPLabs"
    , feedAuthorEmail = "cqplabs@rmit.edu.au"
    , feedRoot        = "http://cqplabs.neophilus.net"
    }

postList :: Tags -> Pattern -> Identifier -> ([Item String] -> Compiler [Item String]) -> Compiler String
postList categories pattern template preprocess' = do
    postItemTpl <- loadBody template
    posts <- loadAll pattern
    processed <- preprocess' posts
    applyTemplateList postItemTpl (tagsCtx categories) processed

