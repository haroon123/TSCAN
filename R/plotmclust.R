#' plotmclust
#' 
#' Plot the model-based clustering results
#'
#' This function will plot the gene expression data after dimension reduction and show the clustering results.
#' 
#' @param mclustobj The exact output of \code{\link{exprmclust}} function.
#' @param x The column of data after dimension reduction to be plotted on the horizontal axis.
#' @param y The column of data after dimension reduction to be plotted on the vertical axis.
#' @param MSTorder The arbitrary order of cluster to be shown on the plot.
#' @param show_tree Whether to show the links between cells connected in the minimum spanning tree.
#' @param show_full_tree Whether to show the full tree or not. Only useful when show_tree=T. Overrides MSTorder.
#' @param show_cell_names Whether to draw the name of each cell in the plot.
#' @param cell_name_size The size of cell name labels if show_cell_names is TRUE.
#' @param markerexpr The gene expression used to define the size of nodes.
#' @return A ggplot2 object.
#' @export
#' @import ggplot2 plyr grid igraph
#' @author Zhicheng Ji, Hongkai Ji <zji4@@zji4.edu>
#' @examples
#' data(lpsdata)
#' procdata <- preprocess(lpsdata)
#' lpsmclust <- exprmclust(procdata)
#' plotmclust(lpsmclust)

plotmclust <- function(mclustobj, x = 1, y = 2, MSTorder = NULL, show_tree = T, show_full_tree = F, show_cell_names = F, cell_name_size = 3, markerexpr = NULL, showcluster = T) {
      color_by = "State"
      
      lib_info_with_pseudo <- data.frame(State=mclustobj$clusterid,sample_name=names(mclustobj$clusterid))
      lib_info_with_pseudo$State <- factor(lib_info_with_pseudo$State)
      S_matrix <- mclustobj$pcareduceres
      pca_space_df <- data.frame(S_matrix[,c(x, y)])
      colnames(pca_space_df) <- c("pca_dim_1","pca_dim_2")
      pca_space_df$sample_name <- row.names(pca_space_df)
      edge_df <- merge(pca_space_df, lib_info_with_pseudo, by.x = "sample_name", by.y = "sample_name")     
      edge_df$Marker <- markerexpr[edge_df$sample_name]
      if (!is.null(markerexpr)) {
            g <- ggplot(data = edge_df, aes(x = pca_dim_1, y = pca_dim_2, size = Marker))
            if (showcluster) {
                  g <- g + geom_point(aes_string(color = color_by, shape=color_by), na.rm = TRUE)      
            } else {
                  g <- g + geom_point(na.rm = TRUE,color="green")
            }
      } else {
            g <- ggplot(data = edge_df, aes(x = pca_dim_1, y = pca_dim_2))
            if (showcluster) {
                  g <- g + geom_point(aes_string(color = color_by, shape=color_by), na.rm = TRUE, size = 3)      
            } else {
                  g <- g + geom_point(na.rm = TRUE, size = 3)
            }
      }
      if (show_cell_names) {
            g <- g + geom_text(aes(label = sample_name), size = cell_name_size)
      }
      
      if (show_tree) {
            clucenter <- mclustobj$clucenter[,c(x,y)]
            clulines <- NULL
            if (show_full_tree) {
                  alledges <- as.data.frame(get.edgelist(mclustobj$MSTtree),stringsAsFactors=F)
                  alledges[,1] <- as.numeric(alledges[,1])
                  alledges[,2] <- as.numeric(alledges[,2])
                  for (i in 1:nrow(alledges)) {
                        clulines <- rbind(clulines, c(clucenter[alledges[i,1],],clucenter[alledges[i,2],]))
                  }      
            } else {
                  if (is.null(MSTorder)) {
                        clutable <- table(mclustobj$clusterid)
                        alldeg <- degree(mclustobj$MSTtree)
                        allcomb <- expand.grid(as.numeric(names(alldeg)[alldeg == 
                                                                              1]), as.numeric(names(alldeg)[alldeg == 1]))
                        allcomb <- allcomb[allcomb[, 1] < allcomb[, 2], ]
                        numres <- t(apply(allcomb, 1, function(i) {
                              tmp <- as.vector(get.shortest.paths(mclustobj$MSTtree, 
                                                                  i[1], i[2])$vpath[[1]])
                              c(length(tmp), sum(clutable[tmp]))
                        }))
                        optcomb <- allcomb[order(numres[, 1], numres[, 2], decreasing = T)[1], ]
                        MSTorder <- get.shortest.paths(mclustobj$MSTtree, optcomb[1], 
                                                       optcomb[2])$vpath[[1]]
                  }
                  for (i in 1:(length(MSTorder)-1)) {
                        clulines <- rbind(clulines, c(clucenter[MSTorder[i],],clucenter[MSTorder[i+1],]))
                  }      
            }
            clulines <- data.frame(x=clulines[,1],xend=clulines[,3],y=clulines[,2],yend=clulines[,4])
            g <- g + geom_segment(aes_string(x="x",xend="xend",y="y",yend="yend",size=NULL),data=clulines,size=1)
            
            clucenter <- data.frame(x=clucenter[,1],y=clucenter[,2],id=1:nrow(clucenter))
            g <- g + geom_text(aes_string(label="id",x="x",y="y",size=NULL),data=clucenter,size=10)
            
      }            
      g <- g + guides(colour = guide_legend(override.aes = list(size=5))) + 
            xlab(paste0("PCA_dimension_",x)) + ylab(paste0("PCA_dimension_",y)) +
            theme(panel.border = element_blank(), axis.line = element_line()) + 
            theme(panel.grid.minor.x = element_blank(), panel.grid.minor.y = element_blank()) + 
            theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_blank()) + 
            theme(legend.position = "top", legend.key.size = unit(0.3, "in"),legend.text = element_text(size = 20),legend.title=element_text(size = 20),legend.box = "vertical") + theme(legend.key = element_blank()) + 
            theme(panel.background = element_rect(fill = "white")) +
            theme(axis.text.x = element_text(size=17,color="black"),
                  axis.text.y = element_text(size=17,color='black'),
                  axis.title.x = element_text(size=20,vjust=-1),
                  axis.title.y = element_text(size=20,vjust=1),
                  plot.margin=unit(c(1,1,1,1),"cm"))       
      g       
}
