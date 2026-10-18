#include "helperFunctions.h"
#include <vector>
#include <set>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <stdio.h>
#include <algorithm>
#include <queue>

long long int squareSequential(int num)
{
    return num * num;
}

bool binarySearchSequential(unsigned int *arr, int l, int r, unsigned int x)
{
    while (l <= r)
    {
        int m = l + (r - l) / 2;

        if (arr[m] == x)
            return true;

        if (arr[m] < x)
            l = m + 1;

        else
            r = m - 1;
    }

    return false;
}

int *deleteVertex(CSRGraph &graph, unsigned int vertex, int *vertexDegrees, unsigned int *numDeletedVertices)
{
    if (vertexDegrees[vertex] <= 0)
    {
        return vertexDegrees;
    }

    for (unsigned int i = graph.srcPtr[vertex]; i < graph.srcPtr[vertex] + graph.degree[vertex]; ++i)
    {
        unsigned int neighbor = graph.dst[i];

        if (vertexDegrees[neighbor] > 0)
        {
            --vertexDegrees[neighbor];
        }
    }

    vertexDegrees[vertex] = -1;
    ++(*numDeletedVertices);
    return vertexDegrees;
}

bool leafReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool hasDeleted = false;
    bool hasChanged;
    do
    {
        hasChanged = false;
        for (unsigned int i = left; i < right + 1; ++i)
        {
            if (vertexDegrees[i] == 1)
            {
                hasChanged = true;
                for (unsigned int j = graph.srcPtr[i]; j < graph.srcPtr[i] + graph.degree[i]; ++j)
                {
                    if (vertexDegrees[graph.dst[j]] > 0)
                    {
                        hasDeleted = true;
                        unsigned int neighbor = graph.dst[j];
                        deleteVertex(graph, neighbor, vertexDegrees, numDeletedVertices);
                    }
                }
            }
        }
    } while (hasChanged);

    return hasDeleted;
}

bool highDegreeReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, int minimum, unsigned int left, unsigned int right)
{
    bool hasDeleted = false;
    bool hasChanged;
    // do
    // {
        hasChanged = false;
        for (unsigned int i = left; i < right + 1; ++i)
        {
            if (vertexDegrees[i] > 0 && vertexDegrees[i] + *numDeletedVertices >= minimum)
            {
                hasChanged = true;
                hasDeleted = true;
                deleteVertex(graph, i, vertexDegrees, numDeletedVertices);
            }
        }
    // } while (hasChanged);

    return hasDeleted;
}

bool triangleReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool hasDeleted = false;
    bool hasChanged;
    // do
    // {
        hasChanged = false;
        for (unsigned int i = left; i < right + 1; ++i)
        {
            if (vertexDegrees[i] == 2)
            {

                unsigned int neighbor1, neighbor2;
                bool foundNeighbor1 = false, keepNeighbors = false;
                for (unsigned int edge = graph.srcPtr[i]; edge < graph.srcPtr[i] + graph.degree[i]; ++edge)
                {
                    unsigned int neighbor = graph.dst[edge];
                    int neighborDegree = vertexDegrees[neighbor];
                    if ( neighborDegree > 0)
                    {
                        if (neighborDegree == 1 || neighborDegree == 2 && neighbor < i)
                        {
                            keepNeighbors = true;
                            break;
                        }
                        else if (!foundNeighbor1)
                        {
                            foundNeighbor1 = true;
                            neighbor1 = neighbor;
                        }
                        else
                        {
                            neighbor2 = neighbor;
                            break;
                        }
                    }
                }

                if (!keepNeighbors)
                {
                    bool found = binarySearchSequential(graph.dst, graph.srcPtr[neighbor2], graph.srcPtr[neighbor2 + 1] - 1, neighbor1);

                    if (found)
                    {
                        hasChanged = true;
                        hasDeleted = true;
                        deleteVertex(graph, neighbor1, vertexDegrees, numDeletedVertices);
                        deleteVertex(graph, neighbor2, vertexDegrees, numDeletedVertices);
                        break;
                    }
                }
            }
        }
    // } while (hasChanged);

    return hasDeleted;
}
bool InducedCliqueReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool graphHasChanged;
    bool applied = false;
    bool inClique;
    std::vector<unsigned int> markedForDeletion(graph.vertexNum,0);
    // do{
        graphHasChanged = false;
        for(unsigned int vertex = left; vertex < right+1; ++vertex){
            int degree = vertexDegrees[vertex];
            unsigned int k = degree+1;
            if(degree>2 && markedForDeletion[vertex]==0) {
                inClique = true;
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(vertexDegrees[neigh]>0 && neigh >= left && neigh <= right) {
                        if (vertexDegrees[neigh]<(k-1) || (neigh<vertex && vertexDegrees[neigh]==k-1)) {
                            inClique = false;
                            break;
                        }
                    }
                }
                if(inClique) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];
                        if(vertexDegrees[neigh]>0 && neigh >= left && neigh <= right) {
                            for(unsigned int edgeN = graph.srcPtr[vertex]; edgeN<graph.srcPtr[vertex + 1]; ++edgeN){
                                unsigned int neighN = graph.dst[edgeN];
                                if(vertexDegrees[neighN]>0 && neighN!=neigh && neighN >= left && neighN <= right){
                                    if(!binarySearchSequential(graph.dst,  graph.srcPtr[neighN], graph.srcPtr[neighN + 1], neigh)){
                                        inClique = false;
                                        break;
                                    }
                                }
                            }                           
                        }
                        if(!inClique) {
                            break;
                        }
                    }
                }
                if(inClique) {
                    for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                        unsigned int neigh = graph.dst[edge];                    
                        if (vertexDegrees[neigh]>0 && neigh >= left && neigh <= right) {
                            markedForDeletion[neigh] = 1;
                        }
                    }

                }
            }
        }
        
       
       
        for (unsigned int vertex = left ; vertex < right+1; ++vertex){
            if(markedForDeletion[vertex]){
                graphHasChanged = true;
                applied = true;
                deleteVertex(graph, vertex, vertexDegrees, numDeletedVertices);
                markedForDeletion[vertex] = 0;
            }
        }
    // }while(graphHasChanged);
    return applied;
    
}
bool cliqueReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    unsigned int maxK = 100;
    bool hasDeleted = false;
    bool inClique;
    std::vector<unsigned int> visited(graph.vertexNum,0);
    
    for (unsigned int vertex = left; vertex < right + 1; ++vertex) {
        
        int k = vertexDegrees[vertex]+1;
        if(k<=maxK && vertexDegrees[vertex]>2 && !visited[vertex]) {
            inClique = true;
            for (unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex]+graph.degree[vertex]; ++edge) {
                unsigned int neigh = graph.dst[edge];
                if(neigh <= right && neigh >= left && vertexDegrees[neigh]>0) {
                    if(vertexDegrees[neigh]!=k-1 || visited[neigh]) {
                        inClique = false;
                        visited[neigh] = 1;
                        break;
                    }
                } else {
                    visited[neigh] = 1;
                }
            }
            if(inClique) {
                std::set<unsigned int> cliqueVertices;
                cliqueVertices.insert(vertex);
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex]+graph.degree[vertex]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(neigh <= right && neigh >= left && vertexDegrees[neigh]>0) {
                        cliqueVertices.insert(neigh);
                    }
                }
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex]+graph.degree[vertex]; ++edge) {
                    unsigned int subject = graph.dst[edge];
                    if(subject <= right && subject >= left && vertexDegrees[subject]>0) {
                        for(unsigned int v = graph.srcPtr[subject]; v<graph.srcPtr[subject]+graph.degree[subject]; ++v) {
                            unsigned int neigh = graph.dst[v];
                            if(neigh <= right && neigh >= left && vertexDegrees[neigh]>0) {
                                if (cliqueVertices.find(neigh) == cliqueVertices.end()) {
                                    inClique = false;
                                    break;
                                }
                            }
                        }
                        if(!inClique) {
                            break;
                        }
                    }  
                }
                if (inClique) {
                    hasDeleted = true;
                    unsigned int counter = 0;
                    vertexDegrees[vertex] = 0;
                    //printf("Clique: %d, ",vertex);
                    for (unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex]+graph.degree[vertex]; ++edge) {
                        unsigned int neighbor = graph.dst[edge];
                        
                        if(neighbor <= right && neighbor >= left && vertexDegrees[neighbor]>0) {
                            //printf("%d, ",neighbor);
                            vertexDegrees[neighbor] = -1;
                            ++(*numDeletedVertices);  
                            ++counter;
                        }
                    }
                    //printf("\n");
                    //printf("Clique Deletion = %d\n",counter);
                }
            }
            
        }
        visited[vertex] = 1;
    }
    return hasDeleted;
}


bool cycleReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool hasDeleted = false;
    std::vector<unsigned int> visited(graph.vertexNum,0);
    
    for(unsigned int i = left; i < right + 1; ++i) {
        if(visited[i] == 0) {
            visited[i] = 1;
            if(vertexDegrees[i]!=2) {
                if (vertexDegrees[i]>0) {
                    for(unsigned int edge = graph.srcPtr[i]; edge<graph.srcPtr[i]+graph.degree[i]; ++edge) {
                        visited[graph.dst[edge]] = 1;
                    }
                }
            } else {
                bool x = false;
                unsigned int second;
                unsigned int last;
                for(unsigned int edge=graph.srcPtr[i]; edge<graph.srcPtr[i]+graph.degree[i]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(neigh >= left && neigh <= right && vertexDegrees[neigh]>0) {
                        if(x) {
                            last = neigh;
                        } else {
                            second = neigh;
                            x = true; 
                        }
                    } else {
                        visited[neigh] = 1;
                    }
                }
                if(vertexDegrees[last] != 2) {
                    visited[last] = 1;
                    visited[second] = 1;
                    continue;
                }
                
                unsigned int first = i;
                std::vector<unsigned int> cycle;
                cycle.push_back(first);
                bool isCycle = true;
                bool done = false;

                while(isCycle) {
                    visited[second] = 1;
                    if(vertexDegrees[second] == 2) {
                        cycle.push_back(second);
                        for(unsigned int edge=graph.srcPtr[second]; edge<graph.srcPtr[second]+graph.degree[second]; ++edge) {
                            unsigned int neigh = graph.dst[edge];
                            if(neigh!=first && neigh >= left && neigh <= right && vertexDegrees[neigh]>0) {
                                if(vertexDegrees[neigh] != 2 || visited[neigh]) {
                                    isCycle = false;
                                    visited[neigh] = 1;
                                    break;
                                } else {
                                    if(neigh!=last) {
                                        first = second;
                                        second = neigh;
                                        break;
                                    } else {
                                        done = true;
                                        cycle.push_back(neigh);
                                        break;
                                    }
                                }
                            }
                            visited[neigh]=1;
                        }
                        if(done) {
                            /*printf("%d\n", i);
                            std::set<unsigned int> hi;
                            for (unsigned int i = 0; i < graph.vertexNum; ++i) {
                                if (vertexDegrees[i]>0) {
                                    for(unsigned int edge = graph.srcPtr[i]; edge<graph.srcPtr[i] + graph.degree[i]; ++edge){
                                        unsigned int neigh = graph.dst[edge];
                                        if(vertexDegrees[neigh]>0) {
                                            if(hi.find(neigh)==hi.end())
                                                printf("%d %d\n",i,neigh);
                                        }
                                    }
                                    hi.insert(i);
                                }
                            }*/
                            
                            //printf("Cycle: ");
                            for(unsigned int j=0; j<cycle.size(); j+=2) {
                                vertexDegrees[cycle[j]] = -1;
                                //printf("%d, ",cycle[j]);
                                if(j<cycle.size()-1) {
                                    vertexDegrees[cycle[j+1]] = 0;
                                    //printf("%d, ",cycle[j+1]);
                                }
                                ++(*numDeletedVertices);  
                            }
                            //printf("\n");
                            //printf("Cycle Deletion = %d\n",cycle.size());
                            hasDeleted = true;
                            break;
                        }    
                    } else {
                        isCycle = false;
                    }
                }
            }
        }
    }
    return hasDeleted;
}
bool DominanceRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right){
    bool graphHasChanged;
    bool applied = false;
    // do{
        graphHasChanged = false;
        for(unsigned int vertex = left; vertex < right+1; ++vertex){ 
            int degree = vertexDegrees[vertex];
            if(degree>2) {
                bool dominating = false;
                for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge) {
                    unsigned int neigh = graph.dst[edge];
                    if(vertexDegrees[neigh] > 0 && (vertexDegrees[neigh]<degree || (vertex < neigh && vertexDegrees[neigh]==degree))) {
                        // check if vertex dominates neigh
                        dominating = true;
                        for(unsigned int edgeN = graph.srcPtr[neigh]; edgeN<graph.srcPtr[neigh + 1]; ++edgeN){
                            unsigned int neighN = graph.dst[edgeN];
                            if(vertexDegrees[neighN]>0 && neighN!=vertex){
                                if(!binarySearchSequential(graph.dst, graph.srcPtr[vertex], graph.srcPtr[vertex + 1]-1, neighN)){
                                    dominating = false;
                                    // printf("vertex %d isn't dominating\n",vertex);
                                    break;
                                }
                               
                            }
                        }
                        if(dominating){
                            // printf("vertex %d is dominating\n",vertex);
                            applied = true;
                            graphHasChanged = true;
                            deleteVertex(graph, vertex, vertexDegrees, numDeletedVertices);
                            break;
                        }
                        else
                            break;
                    }
                }
            }
        }
        
    // }while(graphHasChanged);
    return applied;
}
bool uncofinedVertexReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool graphHasChanged;
    bool applied = false;
    // do{
        graphHasChanged = false;
        for (unsigned int vertex = left; vertex < right + 1; vertex += 1){
            if (vertexDegrees[vertex] <= 2) continue;  

            std::set<unsigned int> S;
            S.insert(vertex);
            std::set<unsigned int> N_S;
            std::unordered_map<unsigned int, unsigned int> deg; // deg[u] = |N(u) ∩ S|

            for (unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; ++edge){
                unsigned int neigh = graph.dst[edge];
                if (vertexDegrees[neigh] > 0){
                    N_S.insert(neigh);
                    deg[neigh] = 1;
                }
            }

            bool deletedVertex = false;
            bool ok = false;
            while (!ok){
                ok = true;
                for (auto u = N_S.begin(); u != N_S.end(); ++u){
                    unsigned int U = *u;
                    if (deg[U] != 1) continue;         
                    
                    int vertexToAdd = -1;
                    for (unsigned int edge = graph.srcPtr[U]; edge < graph.srcPtr[U + 1]; ++edge){
                        unsigned int neighU = graph.dst[edge];
                        if (vertexDegrees[neighU] > 0 && S.find(neighU) == S.end() && N_S.find(neighU) == N_S.end()){
                            if (vertexToAdd == -1){
                                vertexToAdd = neighU;
                            }
                            else{
                                vertexToAdd = -2;
                                break;
                            }
                        }
                    }

                    if (vertexToAdd == -2) continue;   

                    if (vertexToAdd == -1){            
                        applied = true;
                        graphHasChanged = true;
                        deleteVertex(graph, vertex, vertexDegrees, numDeletedVertices);
                        deletedVertex = true;
                        break;
                    }

                    ok = false;
                    S.insert((unsigned int)vertexToAdd);

                    for (unsigned int edge = graph.srcPtr[vertexToAdd]; edge < graph.srcPtr[vertexToAdd + 1]; ++edge){
                        unsigned int w = graph.dst[edge];
                        if (vertexDegrees[w] > 0 && S.find(w) == S.end()){
                            if (N_S.insert(w).second){
                                deg[w] = 1;
                            } else {                  
                                deg[w]++;
                            }
                        }
                    }
                }
            }

            if (deletedVertex) continue;
        }
    // }while(graphHasChanged);
    return applied;
}

//dinicDFS, Finds augmenting path and update the matching, level is used to avoid backpropagation
bool dinicDFS(int vertex, int* iter, int* in, int* out, int* level, int* vertexDegrees, CSRGraph graph){
    while(iter[vertex] >= 0){
        int neigh = graph.dst[graph.srcPtr[vertex] + (iter[vertex]--)];
        int neighN = in[neigh];
        if(vertexDegrees[neigh] <= 0)   
            continue;
        if(neighN < 0 || level[vertex] < level[neighN] && iter[neighN] >= 0 &&
           dinicDFS(neighN, iter, in, out, level, vertexDegrees, graph)){
            out[vertex] = neigh;
            in[neigh] = vertex;
            return true;
        }
    }
    return false;
}
// Builds the levels using BFS and then finds the augmenting paths using DFS, updates the matching
void updateLP(CSRGraph graph, int* vertexDegrees, int* in, int* out, int* level, int* iter,bool* used,unsigned int left, unsigned int right){
    //check if some vertices lost its matched neighbor
    for(unsigned int vertex =left; vertex<=right; ++vertex){
        if(out[vertex] >= 0 && ((vertexDegrees[vertex] > 0) ^ (vertexDegrees[out[vertex]] > 0))) {
            in[out[vertex]] = -1;
            out[vertex] = -1;
        }
    }
    std::vector <int> queue;
    int iterations = 0;
    while(true){
      iterations++;
        for(int i = 0; i < graph.vertexNum * 2; ++i) {
            used[i] = false;
        }
        queue.clear();
        int inserted = 0,processed = 0;
        //the level of unmatched vertices is 0, add them to the queue
        for(int vertex = left ; vertex<= right ; ++vertex){
            if(vertexDegrees[vertex]> 0 && out[vertex]< 0){
                level[vertex] = 0;
                queue.push_back(vertex);
                used[vertex] = true;
                inserted++;
            }
        }
        bool existsAugmentingPath = false;
        //BFS to build the levels
        while(processed < inserted){
            int vertex = queue[processed++];
            iter[vertex] = graph.srcPtr[vertex+1] - graph.srcPtr[vertex]-1;
            for(unsigned int edge = graph.srcPtr[vertex]; edge<graph.srcPtr[vertex+1]; ++edge){
                int neigh = graph.dst[edge];
                if(vertexDegrees[neigh] > 0 && !used[graph.vertexNum + neigh]){
                    used[graph.vertexNum + neigh] = true;
                    int neighN = in[neigh];
                   if(neighN < 0){//so the neighbor is unmatched, augmenting path exists so we not finished yet
                    existsAugmentingPath = true;
                   }
                   else{    
                    level[neighN] = level[vertex]+1;
                    used[neighN] = true;
                    queue.push_back(neighN);
                    inserted++;
                   }
                }
            }
        }
        if(!existsAugmentingPath)
            break;
        // augmenting path search in reverse order
        for(int vertex = (int)right; vertex>= (int)left; --vertex){
            if(vertexDegrees[vertex] > 0 && out[vertex]< 0){
                dinicDFS(vertex, iter, in, out, level, vertexDegrees, graph);
            }
        }
    }

}
//it uses a double graph which means to have a 
//left copy of the vertex which means that the vertex is not in the vertex cover so all its neighbors are in the vertex cover
//and a right copy which means that the vertex in the vertex cover
bool lpReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    unsigned int numDeletedVerticesBefore = *numDeletedVertices;
    bool applied = false;
    int vertexNum = graph.vertexNum;
    int* in = new int[vertexNum];
    int* out = new int[vertexNum];
    int* level = new int[vertexNum * 2];
    int* iter = new int[vertexNum];
    bool* used = new bool[vertexNum*2];

    for(int i = 0; i< vertexNum; ++i){
        in[i] = -1;
        out[i] = -1;
        level[i] = -1;
        iter[i] = -1;
        used[i] = false;
        used[vertexNum + i] = false;
    }
    std::vector<int> queue(vertexNum*2);
    //find the matching stored in in and out.
    updateLP(graph, vertexDegrees, in, out, level, iter, used, left, right);
    //basic deletion, if a vertex is left belongs to Z, but not right exclude it and add its neighbors to the vertex cover since 
    // the cover is [(L-Z) unoin(R inter Z)]
    for (int vertex = left; vertex <= right; ++vertex) {
        if (vertexDegrees[vertex] > 0 && used[vertex] && !used[vertexNum + vertex]) {
            applied = true;
            for (unsigned int i = graph.srcPtr[vertex]; i < graph.srcPtr[vertex] + graph.degree[vertex]; ++i) {
                unsigned int neighbor = graph.dst[i];
                if (vertexDegrees[neighbor] > 0) {
                    deleteVertex(graph, neighbor, vertexDegrees, numDeletedVertices); 
                }
            }
            vertexDegrees[vertex] = -1;   
        }
    }

    int compIdx = 0;
    for(int i = 0; i< vertexNum; ++i){
        iter[i] = 0;
        used[i] = false;
        used[vertexNum + i] = false;
    }
    //Kosaraju's Algorithm to find the strongly connected components(SCC). The idea is to perform a DFS on
    //the double graph and store the vertices in a stack in their finishing order(phase I)
    //Then perform a BFS on the graph to find the SCCs(phase II). 
    for (int s = 0; s < vertexNum; s++){
        if (vertexDegrees[s] > 0 && !used[s]) {
            used[s] = true;
            int inserted = 0;
            queue[inserted] = s;
            while (inserted >= 0) {
                int vertex = queue[inserted];
                int neighbor = -1;
                if (vertex < vertexNum) {
                    while (iter[vertex] < graph.srcPtr[vertex + 1] - graph.srcPtr[vertex]) {
                        neighbor = vertexNum + graph.dst[graph.srcPtr[vertex] + iter[vertex]++];
                        if (vertexDegrees[neighbor - vertexNum] > 0 && !used[neighbor]) {
                            used[neighbor] = true;
                            break;
                        }
                        neighbor = -1;
                    }
                } else if (in[vertex-vertexNum]>=0 && !used[in[vertex - vertexNum]]) {
                    used[in[vertex - vertexNum]] = true;
                    neighbor = in[vertex - vertexNum];
                }

                if (neighbor >= 0) {
                    queue[++inserted] = neighbor;
                } else {
                    level[compIdx++] = vertex;
                    inserted--;
                }
            }
        }
    }

    for(int i = 0; i < vertexNum * 2; ++i) {
        used[i] = false;
    }
    //here the level array is reused to store the vertices in their finishing order
    for (int i = compIdx - 1; i >= 0; i--)
        if (!used[level[i]]) {
            used[level[i]] = true;
            int vertex = level[i];
            int processed = 0, inserted = 0;
            queue[inserted++] = vertex;
            bool oppositeCopyNotFound = true;
            while (processed < inserted) {
                vertex = queue[processed++];
                if (used[vertex >= vertexNum ? (vertex - vertexNum) : (vertex + vertexNum)])
                    oppositeCopyNotFound = false;
                if (vertex >= vertexNum) {
                    for(unsigned int edge = graph.srcPtr[vertex - vertexNum]; edge < graph.srcPtr[vertex - vertexNum + 1]; ++edge){
                        unsigned int neigh = graph.dst[edge];
                        if(vertexDegrees[neigh] > 0 && !used[neigh]){
                            used[neigh] = true;
                            queue[inserted++] = neigh;
                        }
                    }
                } else if (out[vertex]>= 0 && !used[vertexNum + out[vertex]]) {
                    used[vertexNum + out[vertex]] = true;
                    queue[inserted++] = vertexNum + out[vertex];
                }
            }
            if (oppositeCopyNotFound) {
                for (int j = 0; j < inserted; j++) {
                    vertex = queue[j];
                    if (vertex >= vertexNum) {
                        unsigned int v = vertex - vertexNum;
                        if (vertexDegrees[v] <= 0) continue;
                        for (unsigned int i = graph.srcPtr[v]; i < graph.srcPtr[v] + graph.degree[v]; ++i) {
                            unsigned int neighbor = graph.dst[i];
                            if (vertexDegrees[neighbor] > 0) {
                                deleteVertex(graph, neighbor, vertexDegrees, numDeletedVertices);
                            }
                        }
                        vertexDegrees[v] = -1;
                        applied = true;
                    }
                }
            }
    
        }

    delete[] in;
    delete[] out;
    delete[] level;
    delete[] iter;
    delete[] used;
    return applied;
}
		
int cliqueLowerBound(CSRGraph graph, int *vertexDegrees, unsigned int left, unsigned int right)
{
    // prepare the vertices
    std::vector<std::pair<unsigned int, int>> degreesMap;
    int mapSize = 0;
    for (unsigned int vertex = left; vertex < right + 1; ++vertex)
    {
        if (vertexDegrees[vertex] > 0)
        {
            degreesMap.push_back(std::make_pair(vertex, vertexDegrees[vertex]));
            mapSize++;
        }
    }
    std::sort(degreesMap.begin(), degreesMap.end(), [](const std::pair<unsigned int, int>& a, const std::pair<unsigned int, int>& b) {
        return a.second < b.second;
    });
    // calculating the lower bound
    unsigned int clique[graph.vertexNum],size[graph.vertexNum],tmp[graph.vertexNum];
    int lowerBound = 0;
    std::vector<bool> used(graph.vertexNum, false);
    for(int i = 0; i < mapSize; ++i){
        unsigned int vertex = degreesMap[i].first;
        int degree = degreesMap[i].second;
        unsigned int to = vertex, max = 0;
        for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; ++edge){
            unsigned int neigh = graph.dst[edge];
            if(vertexDegrees[neigh] > 0 && used[neigh]){
                tmp[clique[neigh]] = 0;
            }
        }
        for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex + 1]; ++edge){
            unsigned int neigh = graph.dst[edge];
            if(vertexDegrees[neigh] > 0 && used[neigh]){
                unsigned int c = clique[neigh];
					tmp[c]++;
					if (tmp[c] == size[c] && max < size[c]) {
						to = c;
						max = size[c];
					}
				}
        }    
        clique[vertex] = to;
        if (to != vertex) {
            size[to]++;
            lowerBound++;
        } else {
            size[vertex] = 1;
        }
        used[vertex] = true;
    }
    return lowerBound;
}
// The function uses the matching to calculate the cycle cover.
int cycleLowerBound(CSRGraph graph, int *vertexDegrees, unsigned int left, unsigned int right)
{
    //
    int vertexNum = graph.vertexNum;
    int* in = new int[vertexNum];
    int* out = new int[vertexNum];
    int* level = new int[vertexNum * 2];
    int* iter = new int[vertexNum];
    bool* used = new bool[vertexNum*2];

    for(int i = 0; i< vertexNum; ++i){
        in[i] = -1;
        out[i] = -1;
        level[i] = -1;
        iter[i] = -1;
        used[i] = false;
        used[vertexNum + i] = false;
    }
    std::vector<int> queue(vertexNum*2);
    //find the maximum matching
    updateLP(graph, vertexDegrees, in, out, level, iter, used, left, right);
    int* id = iter;
    int lowerBound = 0;
    int* pos = new int[vertexNum];
    int* cycles = level;//reuse of the level array to store the cycles found
    int* cycles2 = new int[vertexNum];
    for(int i = 0; i< vertexNum; ++i){
        id[i] = -1;
    }
    for(int vertex = left; vertex <= right; ++vertex){
        if(vertexDegrees[vertex] >0 && id[vertex] < 0){
            int v = vertex;
            int size = 0;
            // use the matching to find the cycles, while it is possible go out from the vertex go with that path
            // if we reach the same vertex then we have a cycle
            do{
                id[v] = vertex;
                v = out[v];
                if(v == -1)
                  break;
                pos[v] = size;
                cycles[size++] = v;
            } while(v != vertex);
            //check if the obtained cycle is a clique, i.e. if all the vertices are in the same cycle (have same id)
            bool isClique = true;
            for(int j = 0; j< size; ++j){
                int v = cycles[j];
                int num = 0;
                for(unsigned int edge = graph.srcPtr[v]; edge<graph.srcPtr[v+1]; ++edge){
                    unsigned int neigh = graph.dst[edge];
                    if(vertexDegrees[neigh] > 0 && id[neigh] == id[v]){
                        num++;
                    }
                }
                if(num != size-1){
                    isClique = false;
                    break;
                }     
            }
            if(isClique){
                lowerBound += size -1;
            }
            else{
                //when cycle is found, try to break it into smaller cycles with odd sizes since this will result a tighter lower bound
                while(size > 6){
                    int minSize = size, secondCycleStart = 0, firstCycleEnd = size;
                    for(int j = 0; j< size; ++j){
                        for(int k = 0; k < vertexNum; ++k){
                            used[k] = false;
                            used[vertexNum + k] = false;
                        }
                        //for each vertex in cycle check it can be used as separation vertex by being a corner of a quadrilateral
                        //whose all corners belongs to this cycle
                        v = cycles[j];
                        for(unsigned int edge = graph.srcPtr[v]; edge<graph.srcPtr[v+1]; ++edge){
                            unsigned int neigh = graph.dst[edge];
                            if(vertexDegrees[neigh] > 0 && id[neigh] == id[v]){
                                used[neigh] = true;
                            }
                        }
                        v = cycles[(j+1)%size];
                        for(unsigned int edge = graph.srcPtr[v]; edge<graph.srcPtr[v+1]; ++edge){
                            unsigned int neigh = graph.dst[edge];
                            if(vertexDegrees[neigh] > 0 && id[neigh] == id[v] && used[cycles[(pos[neigh]+1)%size]]){
                                int size2 = (pos[neigh] - j + size) % size;
                                if(minSize > size2 && size2 % 2 !=0){
                                    minSize = size2;
                                    secondCycleStart = (j+1)%size;
                                    firstCycleEnd = (pos[neigh]+1)%size;
                                }
                            }
                        }
                    }
                    //if no segmentations found break
                    if(minSize == size){
                        break;
                    }
                    int p = 0;
                    for(int j = firstCycleEnd ; j != secondCycleStart; j = (j+1)%size){
                        cycles2[p++] = cycles[j];
                    }
                    for(int j = secondCycleStart; j!= firstCycleEnd; j = (j+1)%size){
                       id[cycles[j]] = vertexNum;
                    }
                    int* tempCycles = cycles;
                    cycles = cycles2;
                    cycles2 = tempCycles;
                    size -= minSize;
                    lowerBound += (minSize-1)/2;
                    for(int j = 0; j< size; ++j){
                        pos[cycles[j]] = j;
                    }
                }
                lowerBound += (size+1)/2;
            }
        }
    }
    return lowerBound;
}    

int lpLowerBound(CSRGraph graph, int *vertexDegrees, unsigned int left, unsigned int right){
    int remainingVertices = 0;
    for(unsigned int i = left; i < right + 1; ++i) {
        if(vertexDegrees[i] > 0) {
            remainingVertices++;
        }
    }
    return (remainingVertices + 1) / 2;
}