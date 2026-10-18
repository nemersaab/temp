#include "helperFunctions.h"
#include <vector>
#include <set>
#include <stdio.h>
#include <algorithm>
#include <queue>

void generate_graph(CSRGraph &graph){
    FILE *file = fopen("SYNTHETICnew.json", "a");
    if (file == NULL) {
        printf("Failed to open file.\n");
        return;
    }
    fprintf(file, "{\n");
    fprintf(file, "  \"CsrGraph\": {\n");

    fprintf(file, "    \"srcPtrArray\": \"");
    for (unsigned int i = 0; i < graph.vertexNum; i++) {
        fprintf(file, "%d", graph.srcPtr[i]);
        if (i < graph.vertexNum - 1) fprintf(file, " ");
    }
    fprintf(file, "\",\n");

    fprintf(file, "    \"cGraphArray\": \"");
    for (unsigned int i = 0; i < graph.edgeNum * 2; i++) {
        fprintf(file, "%d", graph.dst[i]);
        if (i < graph.edgeNum * 2 - 1) fprintf(file, " ");
    }
    fprintf(file, "\"\n");

    fprintf(file, "  },\n");
    fprintf(file, "  \"Intermediate graphs\": [\n"); // Start the array

    fclose(file);
}


void generate_data(CSRGraph &graph, int *vertexDegrees, unsigned int numDeletedVertices, unsigned int minimum, unsigned int left, unsigned int right, unsigned int label){

    static int first_call = 1;

    FILE *file = fopen("SYNTHETICnew.json", "a");  // Append mode
    if (file == NULL) {
        printf("Failed to open file.\n");
        return;
    }

    if (!first_call) {
        fprintf(file, ",\n");
    }
    first_call = 0;

    fprintf(file, "    {\n");
    fprintf(file, "      \"numDeletedVertices\": %u,\n", numDeletedVertices);
    fprintf(file, "      \"minimum\": %u,\n", minimum);
    fprintf(file, "      \"left\": %u,\n", left);
    fprintf(file, "      \"right\": %u,\n", right);

    fprintf(file, "      \"vertexDegrees\": \"");
    for (unsigned int i = 0; i < graph.vertexNum; ++i) {
        fprintf(file, "%d", vertexDegrees[i]);
        if (i < graph.vertexNum - 1) fprintf(file, " ");
    }
    fprintf(file, "\",\n");

    fprintf(file, "      \"label\": %u\n", label);
    fprintf(file, "    }");

    fclose(file);
    
}
void close_json_file() {
    FILE *file = fopen("SYNTHETICnew.json", "a");
    if (file == NULL) {
        printf("Failed to open file.\n");
        return;
    }

    fprintf(file, "\n  ]\n");
    fprintf(file, "}\n");

    fclose(file);
}

unsigned int strong_branch(CSRGraph &graph,  int *vertexDegrees, unsigned int numDeletedVertices, unsigned int minimum, unsigned int left, unsigned int right){
    
    int best_score = 1000000;//minimum - (int)numDeletedVertices;
    unsigned int best_vertex = left;
    
    int* left_buffer = (int*)calloc(sizeof(int),graph.vertexNum);
    int* right_buffer = (int*)calloc(sizeof(int),graph.vertexNum);
    for(unsigned int vertex = left; vertex < right +1 ; ++vertex){
        if(vertexDegrees[vertex] < 2){
            continue;
        }
        for(unsigned int i = left; i < right + 1; ++i){
            left_buffer[i] = vertexDegrees[i];
            right_buffer[i] = vertexDegrees[i];
        }
        unsigned int left_score = numDeletedVertices;
        unsigned int right_score = numDeletedVertices;

   
        deleteVertex(graph, vertex, left_buffer, &left_score);
        
        for (unsigned int i = graph.srcPtr[vertex]; i < graph.degree[vertex] + graph.srcPtr[vertex]; ++i)
        {
            deleteVertex(graph, graph.dst[i], right_buffer, &right_score);
        }
        //printf("left score before: %d\n",left_score);
        reduce_and_divide(graph, left_buffer, &left_score, minimum, left, right);
        reduce_and_divide(graph, right_buffer, &right_score, minimum, left, right);
        //printf("left score after: %d\n\n",left_score);
        int current_score = (left_score + right_score);
        if(current_score < best_score){
            best_score = current_score;
            best_vertex = vertex;
            if(best_score == 0){
                free(left_buffer);
                free(right_buffer);
                return best_vertex;
            }
        }
           
    }
    free(left_buffer);
    free(right_buffer);
    return best_vertex;
    
}

void reduce_and_divide(CSRGraph &graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int minimum, unsigned int left, unsigned int right){
    
    
    bool leafHasChanged = false, highDegreeHasChanged = false, triangleHasChanged = false, cliqueHasChanged = false, cycleHasChanged = false;
        unsigned int iterationCounter = 0;
        do {
            do
            {
                leafHasChanged = leafReductionRule(graph, vertexDegrees, numDeletedVertices, left, right);
                if (iterationCounter==0 || leafHasChanged || highDegreeHasChanged) {
                    triangleHasChanged = triangleReductionRule(graph, vertexDegrees, numDeletedVertices, left, right);
                } else {
                    triangleHasChanged = false;
                }
                if (iterationCounter==0 || leafHasChanged || triangleHasChanged) {
                    highDegreeHasChanged = highDegreeReductionRule(graph, vertexDegrees, numDeletedVertices, minimum, left, right);
                } else {
                    highDegreeHasChanged = false;
                }
                ++iterationCounter;
            } while (triangleHasChanged || highDegreeHasChanged);

            cliqueHasChanged = 0;
            cycleHasChanged = 0;
            if (cliqueHasChanged || cycleHasChanged) {
                highDegreeHasChanged = highDegreeReductionRule(graph, vertexDegrees, numDeletedVertices, minimum,  left, right);
            }

        } while(highDegreeHasChanged);
    
    unsigned int inside_remaining_vertices = 0;
     
                
    int* inside_components = (int*)malloc(sizeof(int)*graph.vertexNum);
    bool inside_found = true;
    std::queue<unsigned int> inside_q;
    for(unsigned int i = left; i < right + 1; ++i) {
        if(vertexDegrees[i] > 0) {
            ++inside_remaining_vertices;
            inside_components[i] = 0;
            if(inside_found) {
                inside_q.push(i);
                inside_components[i] = 1;
                inside_found = false;
                --inside_remaining_vertices;
            }
        } else {
            inside_components[i] = -1;
        }
    }


    unsigned int inside_counter = 1;

    while(inside_remaining_vertices > 0) {

        if(!inside_q.empty()) {
            unsigned int vertex = inside_q.front();
            inside_q.pop();
            for(unsigned int edge = graph.srcPtr[vertex]; edge < graph.srcPtr[vertex+1]; ++edge) {
                unsigned int neigh = graph.dst[edge];
                if( vertexDegrees[neigh] > 0 && inside_components[neigh] == 0) {
                    inside_components[neigh] = inside_counter;
                    inside_q.push(neigh);
                    --inside_remaining_vertices;   
                }
            }

        } else {
            ++inside_counter;
            for(unsigned int i = left; i < right + 1; ++i ) {
                if(inside_components[i] == 0) {
                    inside_q.push(i);
                    inside_components[i] = inside_counter;
                    --inside_remaining_vertices;
                    break;
                }

            }

        }
    }
    free(inside_components);

    if(minimum<=*numDeletedVertices)
        *numDeletedVertices = 0;
    else
        *numDeletedVertices = (minimum - (int)*numDeletedVertices)/ inside_counter;;
                   
}

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
    do
    {
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
    } while (hasChanged);

    return hasDeleted;
}

bool triangleReductionRule(CSRGraph graph, int *vertexDegrees, unsigned int *numDeletedVertices, unsigned int left, unsigned int right)
{
    bool hasDeleted = false;
    bool hasChanged;
    do
    {
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
    } while (hasChanged);

    return hasDeleted;
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
